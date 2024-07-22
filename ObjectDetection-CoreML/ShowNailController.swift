//
//  ShowNailController.swift
//  YOLO
//
//  Created by Hoang Son Vo Phuoc on 7/16/24.
//  Copyright © 2024 Ultralytics. All rights reserved.
//

import UIKit
import Vision
import ARKit
import SnapKit

class ShowNailController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // Properties
    var nails: [VNRecognizedObjectObservation]
    var screenshot: UIImage
    var rangeOfDegree: Double
    var fromDistance: Double
    var toDistance: Double
    var frame: CGRect
    
    // UI Elements
    private lazy var boxesView: DrawingBoundingBoxView = {
        let view = DrawingBoundingBoxView()
        return view
    }()
    
    private lazy var sceneView: ARSCNView = {
        let view = ARSCNView()
        return view
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    var numberTextField: UITextField!
    
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
    
    private lazy var sliderConf: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.01
        slider.maximumValue = 1
        slider.value = 0.25
        slider.isUserInteractionEnabled = false
        return slider
    }()
    
    private lazy var labelSliderConf: UILabel = {
        let label = UILabel()
        label.text = "0.25 Confidence Threshold"
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 12)
        return label
    }()
    
    private lazy var labelRangeOfDegree: UILabel = {
        let label = UILabel()
        label.text = "Range of degree"
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 12)
        return label
    }()
    
    // Initializer
    init(nails: [VNRecognizedObjectObservation], screenshot: UIImage, frame: CGRect, rangeOfDegree: Double, fromDistance: Double, toDistance: Double) {
        self.nails = nails
        self.screenshot = screenshot
        self.frame = frame
        self.rangeOfDegree = rangeOfDegree
        self.fromDistance = fromDistance
        self.toDistance = toDistance
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        setupSceneView()
        setupImageView()
        setupBoundingBoxView()
        setupUIComponents()
        
        // Start AR session
        startARSession()
        
        // Configure 3D distance after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.configureBoundingBoxView()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
//        boxesView.isDistance3D = false
    }
    
    // Setup Functions
    func setupSceneView() {
        sceneView.frame = frame
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        view.addSubview(sceneView)
    }
    
    func setupImageView() {
        imageView.frame = frame
        imageView.image = screenshot
        view.addSubview(imageView)
    }
    
    func setupBoundingBoxView() {
        boxesView.frame = frame
        boxesView.backgroundColor = .clear
        view.addSubview(boxesView)
    }
    
    func setupUIComponents() {
        setupDismissButton()
        setupNumberTextField()
        setupDistanceFilterUI()
    }
    
    func setupDismissButton() {
        let dismissButton = UIButton()
        dismissButton.setImage(UIImage(named: "delete"), for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        view.addSubview(dismissButton)
        dismissButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.trailing.equalToSuperview().offset(-12)
            make.width.height.equalTo(30)
        }
    }
    
    func setupNumberTextField() {
        view.addSubview(labelSliderConf)
        labelSliderConf.snp.makeConstraints { make in
            make.top.equalTo(boxesView.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(12)
        }
        
        view.addSubview(sliderConf)
        sliderConf.snp.makeConstraints { make in
            make.top.equalTo(labelSliderConf.snp.bottom).offset(10)
            make.leading.equalToSuperview().offset(12)
            make.height.equalTo(30)
            make.width.equalTo(171)
        }
        
        view.addSubview(labelRangeOfDegree)
        labelRangeOfDegree.snp.makeConstraints { make in
            make.top.equalTo(labelSliderConf.snp.top)
            make.trailing.equalToSuperview().offset(-12)
        }
        
        numberTextField = UITextField()
        numberTextField.layer.borderWidth = 1
        numberTextField.layer.borderColor = UIColor.black.cgColor
        numberTextField.isUserInteractionEnabled = false
        numberTextField.layer.cornerRadius = 4
        numberTextField.borderStyle = .roundedRect
        numberTextField.keyboardType = .numberPad
        numberTextField.backgroundColor = .white
        numberTextField.textColor = .black
        numberTextField.textAlignment = .center
        numberTextField.text = "\(Int(rangeOfDegree))"
        view.addSubview(numberTextField)
        
        numberTextField.snp.makeConstraints { make in
            make.trailing.equalTo(labelRangeOfDegree.snp.trailing)
            make.top.equalTo(sliderConf.snp.top)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
    }
    
    func setupDistanceFilterUI() {
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
        fromDistanceTextField.text = "\(Int(fromDistance))"
        fromDistanceTextField.keyboardType = .numberPad
        fromDistanceTextField.isUserInteractionEnabled = false
        fromDistanceTextField.textAlignment = .center
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
        toDistanceTextField.text = "\(Int(toDistance))"
        toDistanceTextField.textAlignment = .center
        toDistanceTextField.keyboardType = .numberPad
        toDistanceTextField.isUserInteractionEnabled = false
        toDistanceTextField.textColor = .black
        view.addSubview(toDistanceTextField)
        
        toDistanceTextField.snp.makeConstraints { make in
            make.top.equalTo(distanceFilterLabel.snp.bottom).offset(10)
            make.centerX.equalToSuperview().offset(35)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
    }
    
    // Configure BoundingBoxView
    func configureBoundingBoxView() {
//        boxesView.isDistance3D = true
        boxesView.predictedObjects = nails
        boxesView.sceneView = sceneView
        boxesView.startDistance = fromDistance
        boxesView.endDistance = toDistance
        boxesView.rangeDegree = rangeOfDegree
    }
    
    // Start AR session
    func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // Dismiss button action
    @objc func dismissButtonTapped() {
        self.dismiss(animated: true, completion: nil)
    }
}


