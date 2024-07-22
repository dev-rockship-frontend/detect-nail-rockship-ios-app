//
//  FaceDetectionViewController.swift
//  ARFaceDetection
//
//  Created by Ioannis Pasmatzis on 12/12/17.
//  Copyright © 2017 Yanniki. All rights reserved.
//

import UIKit
import ARKit
import Vision
import CoreML
import SnapKit

@available(iOS 12.0, *)
class FaceDetectionViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UITextFieldDelegate {
    
    var sceneView: ARSCNView!
    var anchors: [ARAnchor] = []
    var predictions: [VNRecognizedObjectObservation] = []
    var boxesView: DrawingBoundingBoxView!
    var touchCount = 0
    
    private var scanTimer: Timer?
    private var scannedFaceViews = [UIView]()
    var angleTextField: UITextField!
    var filterButton: UIButton!
    
    private lazy var labelRangeOfDegree: UILabel = {
        let label = UILabel()
        label.text = "Range of degree"
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 12)
        return label
    }()
    
    private lazy var sliderConf: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.01
        slider.maximumValue = 1
        slider.value = 0.25
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var labelSliderConf: UILabel = {
        let label = UILabel()
        label.text = "0.25 Confidence Threshold"
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 12)
        return label
    }()
    
    private lazy var fromDistanceTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "from"
        return tf
    }()
    
    private lazy var toDistanceTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "to"
        return tf
    }()
    
    private lazy var faceDetectionModel: VNCoreMLModel = {
        do {
            var model: MLModel
            if #available(iOS 14.0, *) {
                let modelConfig = MLModelConfiguration()
                model = try best().model
            } else {
                guard let modelURL = Bundle.main.url(forResource: "YourModelName", withExtension: "mlmodelc") else {
                    fatalError("Failed to find model file")
                }
                model = try MLModel(contentsOf: modelURL)
            }
            
            let vnCoreMLModel = try VNCoreMLModel(for: model)
            return vnCoreMLModel
        } catch {
            fatalError("Failed to load Core ML model: \(error)")
        }
    }()
    
    private var imageOrientation: CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .right
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        case .unknown, .faceUp, .faceDown, .landscapeLeft: return .up
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupSceneView()
        startARSession()
        setupBoxesView()
        setupSlider()
        setupAngleTextField()
        setupDistanceTextField()
        setupFilterButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        scanTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(scanForFaces), userInfo: nil, repeats: true)
        startARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        scanTimer?.invalidate()
        sceneView.session.pause()
    }
    
    private func setupSceneView() {
        sceneView = ARSCNView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height - 215))
        sceneView.backgroundColor = .white
        sceneView.delegate = self
        sceneView.session.delegate = self
        view.addSubview(sceneView)
    }
    
    private func setupBoxesView() {
        boxesView = DrawingBoundingBoxView(frame: sceneView.bounds)
        boxesView.backgroundColor = .clear
        view.addSubview(boxesView)
    }
    
    func setupAngleTextField() {
        view.addSubview(labelRangeOfDegree)
        labelRangeOfDegree.snp.makeConstraints { make in
            make.top.equalTo(labelSliderConf.snp.top)
            make.trailing.equalToSuperview().offset(-12)
        }
        
        angleTextField = UITextField()
        angleTextField.layer.borderWidth = 1
        angleTextField.layer.borderColor = UIColor.black.cgColor
        angleTextField.layer.cornerRadius = 4
        angleTextField.borderStyle = .roundedRect
        angleTextField.keyboardType = .numberPad
        angleTextField.backgroundColor = .white
        angleTextField.textColor = .black
        angleTextField.textAlignment = .center
        angleTextField.delegate = self
        angleTextField.text = "5"
        view.addSubview(angleTextField)
        
        angleTextField.snp.makeConstraints { make in
            make.trailing.equalTo(labelRangeOfDegree.snp.trailing)
            make.top.equalTo(sliderConf.snp.top)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
    }
    
    func setupSlider() {
        
        view.addSubview(labelSliderConf)
        labelSliderConf.snp.makeConstraints { make in
            make.top.equalTo(sceneView.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(12)
        }
        
        view.addSubview(sliderConf)
        sliderConf.snp.makeConstraints { make in
            make.top.equalTo(labelSliderConf.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(12)
            make.height.equalTo(30)
            make.width.equalTo(171)
        }
    }
    
    private func setupDistanceTextField(){
        let distanceFilterLabel = UILabel()
        distanceFilterLabel.text = "Distance Filter (mm)"
        distanceFilterLabel.textColor = .black
        distanceFilterLabel.font = UIFont.systemFont(ofSize: 12)
        view.addSubview(distanceFilterLabel)
        
        distanceFilterLabel.snp.makeConstraints { make in
            make.top.equalTo(sliderConf.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
        }
        
        fromDistanceTextField.layer.borderWidth = 1
        fromDistanceTextField.layer.borderColor = UIColor.black.cgColor
        fromDistanceTextField.layer.cornerRadius = 4
        fromDistanceTextField.text = "50"
        fromDistanceTextField.keyboardType = .numberPad
        fromDistanceTextField.textAlignment = .center
        fromDistanceTextField.delegate = self
        fromDistanceTextField.textColor = .black
        view.addSubview(fromDistanceTextField)
        
        fromDistanceTextField.snp.makeConstraints { make in
            make.top.equalTo(distanceFilterLabel.snp.bottom).offset(10)
            make.centerX.equalToSuperview().offset(-35)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
        
        toDistanceTextField.layer.borderWidth = 1
        toDistanceTextField.layer.borderColor = UIColor.black.cgColor
        toDistanceTextField.layer.cornerRadius = 4
        toDistanceTextField.text = "150"
        toDistanceTextField.textAlignment = .center
        toDistanceTextField.keyboardType = .numberPad
        toDistanceTextField.delegate = self
        toDistanceTextField.textColor = .black
        view.addSubview(toDistanceTextField)
        
        toDistanceTextField.snp.makeConstraints { make in
            make.top.equalTo(distanceFilterLabel.snp.bottom).offset(10)
            make.centerX.equalToSuperview().offset(35)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
    }
    
    func setupFilterButton() {
        filterButton = UIButton(type: .system)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.isEnabled = false
        filterButton.setTitle("Filter", for: .normal)
        filterButton.setTitleColor(.black, for: .normal)
        filterButton.layer.borderWidth = 1
        filterButton.layer.cornerRadius = 5
        filterButton.layer.borderColor = UIColor.black.cgColor
        filterButton.backgroundColor = .lightGray.withAlphaComponent(0.3)
        filterButton.addTarget(self, action: #selector(filterAnchors), for: .touchUpInside)
        view.addSubview(filterButton)
        
        filterButton.snp.makeConstraints { make in
            make.top.equalTo(toDistanceTextField.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(35)
        }
    }
    
    @objc private func scanForFaces() {
        _ = scannedFaceViews.map { $0.removeFromSuperview() }
        scannedFaceViews.removeAll()
        
        guard let currentFrame = sceneView.session.currentFrame else { return }
        let capturedImage = currentFrame.capturedImage
        let image = CIImage(cvPixelBuffer: capturedImage)
        
        let request = VNCoreMLRequest(model: faceDetectionModel) { [weak self] (request, error) in
            DispatchQueue.main.async {
                if #available(iOS 12.0, *) {
                    if let results = request.results as? [VNRecognizedObjectObservation] {
                        self?.predictions = results
                        DispatchQueue.main.async {
                            self?.boxesView.predictedObjects = results
                            self?.boxesView.sceneView = self?.sceneView
                        }
                    }
                } else {
                    // Fallback on earlier versions
                }
            }
        }
        
        DispatchQueue.global().async {
            try? VNImageRequestHandler(ciImage: image, orientation: self.imageOrientation).perform([request])
        }
    }
    
    @objc func sliderChanged(_ sender: Any) {
        let conf = Double(round(100 * sliderConf.value)) / 100
        self.labelSliderConf.text = String(conf) + " Confidence Threshold"
        faceDetectionModel.featureProvider = ThresholdProvider(iouThreshold: 0.45, confidenceThreshold: conf)
    }
    
    @objc func filterAnchors() {
        self.boxesView.rangeDegree = Double(angleTextField.text ?? "") ?? 0
        self.boxesView.startDistance = Double(fromDistanceTextField.text ?? "") ?? 0
        self.boxesView.endDistance = Double(toDistanceTextField.text ?? "") ?? 0
        
        filterButton.isEnabled = false
        filterButton.backgroundColor = .lightGray.withAlphaComponent(0.3)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let fromDistanceText = fromDistanceTextField.text ?? ""
        let toDistanceText = toDistanceTextField.text ?? ""
        let angleTextField = angleTextField.text ?? ""
        //        print("Number entered: \(numberText)")
        //        rangeDegree = Double(String(numberText)) ?? 5
        
        guard let fromDistance = Double(fromDistanceText), let toDistance = Double(toDistanceText), let rangeDegree = Double(String(angleTextField))  else {
            showAlert(message: "Invalid distance range. Please enter valid distances.")
            return
        }
        
        guard !toDistanceText.isEmpty else {
            showAlert(message: "To distance cannot be empty. Please enter a valid distance.")
            return
        }
        
        guard !angleTextField.isEmpty else {
            showAlert(message: "To distance cannot be empty. Please enter a valid distance.")
            return
        }
        
        
        guard toDistance > fromDistance else {
            showAlert(message: "To distance must be greater than from distance. Please enter a valid distance range.")
            return
        }
        
        if rangeDegree != 5 || toDistance != 50 || fromDistance != 150 {
            filterButton.isEnabled = true
            filterButton.backgroundColor = .blue.withAlphaComponent(0.3)
        } else {
            filterButton.isEnabled = false
            filterButton.backgroundColor = .lightGray.withAlphaComponent(0.3)
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Invalid Input", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func calculateDistance(from point1: SCNVector3, to point2: SCNVector3) -> Float {
        let vector = SCNVector3(point2.x - point1.x, point2.y - point1.y, point2.z - point1.z)
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
    
    private func convertBoundingBoxTo3D(_ boundingBox: CGRect) -> SCNVector3? {
        let viewSize = sceneView.bounds.size
        
        // Calculate 2D points
        let topLeft = CGPoint(x: boundingBox.minX * viewSize.width, y: boundingBox.minY * viewSize.height)
        let bottomRight = CGPoint(x: boundingBox.maxX * viewSize.width, y: boundingBox.maxY * viewSize.height)
        let center = CGPoint(x: (topLeft.x + bottomRight.x) / 2, y: (topLeft.y + bottomRight.y) / 2)
        
        // Convert 2D points to 3D
        let hitTestResults = sceneView.hitTest(center, types: .featurePoint)
        if let result = hitTestResults.first {
            let position = result.worldTransform.columns.3
            return SCNVector3(position.x, position.y, position.z)
        }
        
        return nil
    }
    
    private func faceFrame(from boundingBox: CGRect) -> CGRect {
        let origin = CGPoint(x: boundingBox.minX * sceneView.bounds.width, y: (1 - boundingBox.maxY) * sceneView.bounds.height)
        let size = CGSize(width: boundingBox.width * sceneView.bounds.width, height: boundingBox.height * sceneView.bounds.height)
        return CGRect(origin: origin, size: size)
    }
    
    func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let sphere = SCNSphere(radius: 0.003)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        sphere.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphere)
        node.addChildNode(sphereNode)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        self.anchors.append(contentsOf: anchors)
        if self.anchors.count == 2 {
            calculateDistance()
        }
    }
    
    func distanceBetweenPoints(point1: SCNVector3, point2: SCNVector3) -> Float {
        let vector = SCNVector3(point2.x - point1.x, point2.y - point1.y, point2.z - point1.z)
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
    
    func calculateDistance() {
        guard anchors.count <= 2 else { return }
        
        let transform1 = anchors[0].transform
        let transform2 = anchors[1].transform
        
        let position1 = SCNVector3(transform1.columns.3.x, transform1.columns.3.y, transform1.columns.3.z)
        let position2 = SCNVector3(transform2.columns.3.x, transform2.columns.3.y, transform2.columns.3.z)
        
        // Calculate distance between points
        let distance = distanceBetweenPoints(point1: position1, point2: position2)
        let distanceInCentimeters = distance * 100
        
        
        // Remove previous line node if exists
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "lineNode" {
                node.removeFromParentNode()
            }
        }
        
        // Create line geometry
        let lineGeometry = SCNGeometry.line(from: position1, to: position2)
        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.name = "lineNode"
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue // Change color here
        lineGeometry.materials = [material]
        
        // Add line node to scene
        sceneView.scene.rootNode.addChildNode(lineNode)
    }
}

extension SCNGeometry {
    static func line(from vector1: SCNVector3, to vector2: SCNVector3) -> SCNGeometry {
        let sources = SCNGeometrySource(vertices: [vector1, vector2])
        let indices: [UInt32] = [0, 1]
        let elements = SCNGeometryElement(indices: indices, primitiveType: .line)
        return SCNGeometry(sources: [sources], elements: [elements])
    }
}





/*
 
 //
 //  FaceDetectionViewController.swift
 //  ARFaceDetection
 //
 //  Created by Ioannis Pasmatzis on 12/12/17.
 //  Copyright © 2017 Yanniki. All rights reserved.
 //
 
 import UIKit
 import ARKit
 import Vision
 import CoreML
 import SnapKit
 
 @available(iOS 12.0, *)
 class FaceDetectionViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
 
 var sceneView: ARSCNView!
 var distanceLabel: UILabel!
 var resetButton: UIButton!
 var anchors: [ARAnchor] = []
 var predictions: [VNRecognizedObjectObservation] = []
 var boxesView: DrawingBoundingBoxView!
 var touchCount = 0
 
 private var scanTimer: Timer?
 private var scannedFaceViews = [UIView]()
 
 // Load the Core ML model
 private lazy var faceDetectionModel: VNCoreMLModel = {
 do {
 var model: MLModel
 
 // Check if iOS version supports MLModelConfiguration
 if #available(iOS 14.0, *) {
 let modelConfig = MLModelConfiguration()
 model = try best().model
 } else {
 // Fallback for earlier iOS versions
 // Load your model using a different method suitable for older iOS versions
 guard let modelURL = Bundle.main.url(forResource: "YourModelName", withExtension: "mlmodelc") else {
 fatalError("Failed to find model file")
 }
 model = try MLModel(contentsOf: modelURL)
 }
 
 let vnCoreMLModel = try VNCoreMLModel(for: model)
 return vnCoreMLModel
 } catch {
 fatalError("Failed to load Core ML model: \(error)")
 }
 }()
 
 // Get the orientation of the image that corresponds to the current device orientation
 private var imageOrientation: CGImagePropertyOrientation {
 switch UIDevice.current.orientation {
 case .portrait: return .right
 case .landscapeRight: return .down
 case .portraitUpsideDown: return .left
 case .unknown, .faceUp, .faceDown, .landscapeLeft: return .up
 }
 }
 
 override func viewDidLoad() {
 super.viewDidLoad()
 
 sceneView = ARSCNView()
 view.addSubview(sceneView)
 
 sceneView.delegate = self
 sceneView.session.delegate = self
 
 sceneView.snp.makeConstraints { make in
 make.edges.equalTo(view.safeAreaLayoutGuide)
 }
 
 startARSession()
 
 // Initialize boxesView
 boxesView = DrawingBoundingBoxView(frame: view.bounds)
 boxesView.backgroundColor = .clear
 view.addSubview(boxesView)
 
 setupDistanceLabel()
 setupResetButton()
 }
 
 override func viewWillAppear(_ animated: Bool) {
 super.viewWillAppear(animated)
 
 let configuration = ARWorldTrackingConfiguration()
 configuration.planeDetection = .horizontal
 sceneView.session.run(configuration)
 
 // Scan for faces in regular intervals
 scanTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(scanForFaces), userInfo: nil, repeats: true)
 startARSession()
 distanceLabel.text = "Distance: 0 cm"
 }
 
 override func viewWillDisappear(_ animated: Bool) {
 super.viewWillDisappear(animated)
 
 scanTimer?.invalidate()
 sceneView.session.pause()
 }
 
 @objc private func scanForFaces() {
 _ = scannedFaceViews.map { $0.removeFromSuperview() }
 scannedFaceViews.removeAll()
 
 guard let currentFrame = sceneView.session.currentFrame else { return }
 let capturedImage = currentFrame.capturedImage
 let image = CIImage(cvPixelBuffer: capturedImage)
 
 let request = VNCoreMLRequest(model: faceDetectionModel) { [weak self] (request, error) in
 DispatchQueue.main.async {
 if #available(iOS 12.0, *) {
 if let results = request.results as? [VNRecognizedObjectObservation] {
 self?.predictions = results
 DispatchQueue.main.async {
 self?.boxesView.predictedObjects = results
 self?.boxesView.sceneView = self?.sceneView
 }
 }
 } else {
 // Fallback on earlier versions
 }
 }
 }
 
 DispatchQueue.global().async {
 try? VNImageRequestHandler(ciImage: image, orientation: self.imageOrientation).perform([request])
 }
 }
 
 private func calculateDistance(from point1: SCNVector3, to point2: SCNVector3) -> Float {
 let vector = SCNVector3(point2.x - point1.x, point2.y - point1.y, point2.z - point1.z)
 return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
 }
 
 private func convertBoundingBoxTo3D(_ boundingBox: CGRect) -> SCNVector3? {
 let viewSize = sceneView.bounds.size
 
 // Calculate 2D points
 let topLeft = CGPoint(x: boundingBox.minX * viewSize.width, y: boundingBox.minY * viewSize.height)
 let bottomRight = CGPoint(x: boundingBox.maxX * viewSize.width, y: boundingBox.maxY * viewSize.height)
 let center = CGPoint(x: (topLeft.x + bottomRight.x) / 2, y: (topLeft.y + bottomRight.y) / 2)
 
 // Convert 2D points to 3D
 let hitTestResults = sceneView.hitTest(center, types: .featurePoint)
 if let result = hitTestResults.first {
 let position = result.worldTransform.columns.3
 return SCNVector3(position.x, position.y, position.z)
 }
 
 return nil
 }
 
 private func faceFrame(from boundingBox: CGRect) -> CGRect {
 let origin = CGPoint(x: boundingBox.minX * sceneView.bounds.width, y: (1 - boundingBox.maxY) * sceneView.bounds.height)
 let size = CGSize(width: boundingBox.width * sceneView.bounds.width, height: boundingBox.height * sceneView.bounds.height)
 return CGRect(origin: origin, size: size)
 }
 
 func startARSession() {
 let configuration = ARWorldTrackingConfiguration()
 sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
 }
 
 func setupDistanceLabel() {
 distanceLabel = UILabel()
 distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
 distanceLabel.textColor = UIColor.white
 distanceLabel.textAlignment = .center
 distanceLabel.text = "Distance: 0 cm"
 self.view.addSubview(distanceLabel)
 
 distanceLabel.snp.makeConstraints { make in
 make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-35)
 make.leading.equalToSuperview().offset(50)
 make.trailing.equalToSuperview().offset(-50)
 }
 }
 
 func setupResetButton() {
 resetButton = UIButton(type: .system)
 resetButton.setTitle("Reset", for: .normal)
 resetButton.addTarget(self, action: #selector(resetAnchors), for: .touchUpInside)
 view.addSubview(resetButton)
 
 resetButton.snp.makeConstraints { make in
 make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
 make.centerX.equalToSuperview()
 make.width.equalTo(48)
 make.height.equalTo(40)
 }
 }
 
 @objc func resetAnchors() {
 anchors.removeAll()
 distanceLabel.text = "Distance: 0 cm"
 touchCount = 0 // Reset the touch count
 
 // Remove all existing nodes
 sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
 node.removeFromParentNode()
 }
 }
 
 override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
 guard let touch = touches.first else { return }
 let location = touch.location(in: sceneView)
 
 let hitTestResults = sceneView.hitTest(location, types: .featurePoint)
 if let result = hitTestResults.first {
 if touchCount < 2 {
 let anchor = ARAnchor(transform: result.worldTransform)
 sceneView.session.add(anchor: anchor)
 touchCount += 1
 } else {
 resetAnchors()
 }
 }
 }
 
 func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
 let sphere = SCNSphere(radius: 0.003)
 let material = SCNMaterial()
 material.diffuse.contents = UIColor.blue
 sphere.materials = [material]
 
 let sphereNode = SCNNode(geometry: sphere)
 node.addChildNode(sphereNode)
 }
 
 func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
 self.anchors.append(contentsOf: anchors)
 if self.anchors.count == 2 {
 calculateDistance()
 }
 }
 
 func distanceBetweenPoints(point1: SCNVector3, point2: SCNVector3) -> Float {
 let vector = SCNVector3(point2.x - point1.x, point2.y - point1.y, point2.z - point1.z)
 return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
 }
 
 func calculateDistance() {
 guard anchors.count <= 2 else { return }
 
 let transform1 = anchors[0].transform
 let transform2 = anchors[1].transform
 
 let position1 = SCNVector3(transform1.columns.3.x, transform1.columns.3.y, transform1.columns.3.z)
 let position2 = SCNVector3(transform2.columns.3.x, transform2.columns.3.y, transform2.columns.3.z)
 
 // Calculate distance between points
 let distance = distanceBetweenPoints(point1: position1, point2: position2)
 let distanceInCentimeters = distance * 100
 
 // Update distance label
 distanceLabel.text = String(format: "Distance: %.2f cm", distanceInCentimeters)
 
 // Remove previous line node if exists
 sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
 if node.name == "lineNode" {
 node.removeFromParentNode()
 }
 }
 
 // Create line geometry
 let lineGeometry = SCNGeometry.line(from: position1, to: position2)
 let lineNode = SCNNode(geometry: lineGeometry)
 lineNode.name = "lineNode"
 
 let material = SCNMaterial()
 material.diffuse.contents = UIColor.blue // Change color here
 lineGeometry.materials = [material]
 
 // Add line node to scene
 sceneView.scene.rootNode.addChildNode(lineNode)
 }
 }
 
 extension SCNGeometry {
 static func line(from vector1: SCNVector3, to vector2: SCNVector3) -> SCNGeometry {
 let sources = SCNGeometrySource(vertices: [vector1, vector2])
 let indices: [UInt32] = [0, 1]
 let elements = SCNGeometryElement(indices: indices, primitiveType: .line)
 return SCNGeometry(sources: [sources], elements: [elements])
 }
 }
 */
