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
        
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        
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
    
    
    @objc
    private func scanForFaces() {
        _ = scannedFaceViews.map { $0.removeFromSuperview() }
        scannedFaceViews.removeAll()
        
//        guard let capturedImage = sceneView.session.currentFrame?.capturedImage else { return }
//        
//        let image = CIImage(cvPixelBuffer: capturedImage)
        
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
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        distanceLabel.textColor = UIColor.white
        distanceLabel.textAlignment = .center
        distanceLabel.text = "Distance: 0 cm"
        self.view.addSubview(distanceLabel)
        
        distanceLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -35).isActive = true
        distanceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50).isActive = true
        distanceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50).isActive = true
    }
    
    func setupResetButton() {
        resetButton = UIButton(type: .system)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setTitle("Reset", for: .normal)
        
        resetButton.addTarget(self, action: #selector(resetAnchors), for: .touchUpInside)
        view.addSubview(resetButton)
        
        NSLayoutConstraint.activate([
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            resetButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resetButton.widthAnchor.constraint(equalToConstant: 48),
            resetButton.heightAnchor.constraint(equalToConstant: 40)
        ])
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
        
        
        // Adjust line width
        //            lineNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        //            lineNode.geometry?.firstMaterial?.specular.contents = UIColor.red
        //            lineNode.geometry?.firstMaterial?.emission.contents = UIColor.green
        //            lineNode.geometry?.firstMaterial?.transparency = 0.5
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


