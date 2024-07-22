//
//  DrawingBoundingBoxView.swift
//  SSDMobileNet-CoreML
//
//  Created by GwakDoyoung on 04/02/2019.
//  Copyright © 2019 tucan9389. All rights reserved.
//


import UIKit
import Vision
import ARKit


class DrawingBoundingBoxView: UIView {
    
    // Properties
    //    var isDistance3D: Bool = false
    var rangeDegree: Double = 5.0
    var startDistance: Double = 50.0
    var endDistance: Double = 150.0
    var sceneView: ARSCNView?
    
    static private var colors: [String: UIColor] = [:]
    
    // Predicted objects to display
    public var predictedObjects: [VNRecognizedObjectObservation] = [] {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    // Enum for axis
    enum Axis {
        case x
        case y
    }
    
    // Function to get label color
    public func labelColor(with label: String) -> UIColor {
        if let color = DrawingBoundingBoxView.colors[label] {
            return color
        } else {
            let color = UIColor(hue: .random(in: 0...1), saturation: 1, brightness: 1, alpha: 0.8)
            DrawingBoundingBoxView.colors[label] = color
            return color
        }
    }
    
    // Override draw function
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)
        //        drawBoundingBoxes()
        drawBoundingBoxes(on: sceneView)
        drawConnectingLines(context: context)
    }
    
    // Draw bounding boxes for predicted objects
    //    func drawBoundingBoxes() {
    //        guard let sceneView = sceneView else {
    //            debugPrint("sceneView = nil ")
    //            return
    //        }
    //
    //        sceneView.subviews.forEach({ $0.removeFromSuperview() })
    //
    //        for prediction in predictedObjects {
    //            createLabelAndBox(prediction: prediction, on: sceneView)
    //        }
    //    }
    
    // Create label and box for each prediction
    //    func createLabelAndBox(prediction: VNRecognizedObjectObservation) {
    //        let scale = CGAffineTransform.identity.scaledBy(x: bounds.width, y: bounds.height)
    //        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
    //        let bgRect = prediction.boundingBox.applying(transform).applying(scale)
    //
    //        let bgView = UIView(frame: bgRect)
    //        bgView.layer.borderColor = UIColor.green.cgColor
    //        bgView.layer.borderWidth = 1
    //        bgView.backgroundColor = UIColor.clear
    //        addSubview(bgView)
    //    }
    
    func createLabelAndBox(prediction: VNRecognizedObjectObservation, on sceneView: ARSCNView) {
        // Chuyển đổi bounding box từ hệ tọa độ của ARKit sang hệ tọa độ của sceneView
        let boundingBox = prediction.boundingBox
        let minX = boundingBox.minX * sceneView.bounds.width
        let minY = (1 - boundingBox.maxY) * sceneView.bounds.height
        let width = boundingBox.width * sceneView.bounds.width
        let height = boundingBox.height * sceneView.bounds.height
        
        // Kiểm tra nếu bounding box nằm trong phạm vi hợp lý
        //        guard minX >= 0, minY >= 0, minX + width <= sceneView.bounds.width, minY + height <= sceneView.bounds.height else {
        //            return
        //        }
        
        // Chuyển đổi tọa độ 3D của các góc bounding box sang tọa độ 2D của sceneView
        let topLeft = sceneView.projectPoint(SCNVector3(minX, minY, 0))
        let topRight = sceneView.projectPoint(SCNVector3(minX + width, minY, 0))
        let bottomLeft = sceneView.projectPoint(SCNVector3(minX, minY + height, 0))
        let bottomRight = sceneView.projectPoint(SCNVector3(minX + width, minY + height, 0))
        
        // Kiểm tra nếu các tọa độ 2D này nằm trong phạm vi của sceneView
        let points = [topLeft, topRight, bottomLeft, bottomRight]
        //        guard points.allSatisfy({ $0.x >= 0 && $0.x <= Float(sceneView.bounds.width) && $0.y >= 0 && $0.y <= Float(sceneView.bounds.height) }) else {
        //            debugPrint("allSatisfy = nil")
        //            return
        //        }
        
        let bgRect = CGRect(x: minX, y: minY, width: width, height: height)
        
        let bgView = UIView(frame: bgRect)
        bgView.layer.borderColor = UIColor.green.cgColor
        bgView.layer.borderWidth = 1
        bgView.backgroundColor = UIColor.clear
        sceneView.addSubview(bgView)
        //        scannedFaceViews.append(bgView)
    }
    
    func drawBoundingBoxes(on sceneView: ARSCNView?) {
        guard let sceneView = sceneView else { return }
        
        // Xóa tất cả các subviews của sceneView
        sceneView.subviews.forEach({ $0.removeFromSuperview() })
        subviews.forEach({ $0.removeFromSuperview() })
        
        
        debugPrint("predictedObjects :\(predictedObjects.count)")
        
        for prediction in predictedObjects {
            createLabelAndBox(prediction: prediction, on: sceneView)
        }
    }
    
    // Draw connecting lines between points
    func drawConnectingLines(context: CGContext) {
        guard predictedObjects.count > 1 else { return }
        
        let points = predictedObjects.map { prediction -> CGPoint in
            let scale = CGAffineTransform.identity.scaledBy(x: bounds.width, y: bounds.height)
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
            let centerRect = prediction.boundingBox.applying(transform).applying(scale)
            return CGPoint(x: centerRect.midX, y: centerRect.midY)
        }
        
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(2.0)
        
        drawLinesThroughPoints(context: context, points: points)
    }
    
    // Display distance label at a given point
    func displayDistanceLabel(at point: CGPoint, distance: String) {
        let distanceLabel = UILabel()
        distanceLabel.text = distance
        distanceLabel.font = UIFont.systemFont(ofSize: 12)
        distanceLabel.textColor = .white
        distanceLabel.sizeToFit()
        distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        distanceLabel.layer.cornerRadius = 5
        distanceLabel.clipsToBounds = true
        distanceLabel.center = point
        addSubview(distanceLabel)
    }
    
    // Calculate distance between two 3D points
    private func calculateDistance(from point1: SCNVector3, to point2: SCNVector3) -> Float {
        let vector = SCNVector3(point2.x - point1.x, point2.y - point1.y, point2.z - point2.z)
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
    
    // Convert 2D bounding box point to 3D point
    private func convertBoundingBoxTo3D(_ point: CGPoint) -> SCNVector3? {
        guard let sceneView = self.sceneView else {
            return nil
        }
        
        let hitTestResults = sceneView.hitTest(point, types: .featurePoint)
        if let result = hitTestResults.first {
            let position = result.worldTransform.columns.3
            return SCNVector3(position.x, position.y, position.z)
        }
        
        return nil
    }
    
    private func convert2Dto3D(_ point: CGPoint) -> SCNVector3? {
        let nearVector = SCNVector3(x: Float(point.x), y: Float(point.y), z: 0)
        
        guard let sceneView = sceneView else {
            return nil
        }
        let nearScenePoint = sceneView.unprojectPoint(nearVector)
        let farVector = SCNVector3(x: Float(point.x), y: Float(point.y), z: 1)
        let farScenePoint = sceneView.unprojectPoint(farVector)
        
        let viewVector = SCNVector3(x: Float(farScenePoint.x - nearScenePoint.x), y: Float(farScenePoint.y - nearScenePoint.y), z: Float(farScenePoint.z - nearScenePoint.z))
        
        let vectorLength = sqrt(viewVector.x*viewVector.x + viewVector.y*viewVector.y + viewVector.z*viewVector.z)
        let normalizedViewVector = SCNVector3(x: viewVector.x/vectorLength, y: viewVector.y/vectorLength, z: viewVector.z/vectorLength)
        
        let scale = Float(15)
        let scenePoint = SCNVector3(x: normalizedViewVector.x*scale, y: normalizedViewVector.y*scale, z: normalizedViewVector.z*scale)
        
        print("2D point: \(point). 3D point: \(nearScenePoint). Far point: \(farScenePoint). scene point: \(scenePoint)")
        
        return scenePoint
    }
    
    // Draw lines through points with additional logic for angle and distance checks
    //    func drawLinesThroughPoints(context: CGContext, points: [CGPoint]) {
    //        let edges = createEdges(points: points)
    //        let mstEdges = kruskal(points: points, edges: edges)
    //
    //        context.beginPath()
    //
    //        for edge in mstEdges {
    //            let x1 = edge.0.x, y1 = edge.0.y
    //            let x2 = edge.1.x, y2 = edge.1.y
    //
    //            let angleX = isAngleOfDeviationGreaterThanFiveDegrees(x1: x1, y1: y1, x2: x2, y2: y2, withRespectTo: .x).rounded()
    //            let angleY = isAngleOfDeviationGreaterThanFiveDegrees(x1: x1, y1: y1, x2: x2, y2: y2, withRespectTo: .y).rounded()
    //
    //            var angle = ""
    //            if angleX <= rangeDegree {
    //                angle = "\(Int(angleX))"
    //            } else if angleY <= rangeDegree {
    //                angle = "\(Int(angleY))"
    //            }
    //
    //            if angleX <= rangeDegree || angleY <= rangeDegree {
    //                if isDistance3D {
    //                    if let point1_3D = convertBoundingBoxTo3D(edge.0), let point2_3D = convertBoundingBoxTo3D(edge.1) {
    //                        let distance = Double(calculateDistance(from: point1_3D, to: point2_3D) * 1000)
    //
    //                        if distance >= startDistance && distance <= endDistance {
    //                            context.move(to: edge.0)
    //                            context.addLine(to: edge.1)
    //
    //                            let midpoint = CGPoint(x: (edge.0.x + edge.1.x) / 2, y: (edge.0.y + edge.1.y) / 2)
    //                            displayDistanceLabel(at: midpoint, distance: "\(Int(distance)), \(angle)")
    //                        }
    //                    } else {
    //                        print("Failed to get 3D coordinates for nails.")
    //                    }
    //                }
    //            }
    //        }
    //        context.strokePath()
    //    }
    
    
    func drawLinesThroughPoints(context: CGContext, points: [CGPoint]) {
        let edges = createEdges(points: points).sorted { $0.2 < $1.2 }
        
        var connectionCounts = [CGPoint: Int]()
        
        for point in points {
            connectionCounts[point] = 0
        }
        
        context.beginPath()
        
        for edge in edges {
            let (point1, point2, distance) = edge
            
            if connectionCounts[point1]! < 4 && connectionCounts[point2]! < 4 {
                let angleX = isAngleOfDeviationGreaterThanFiveDegrees(x1: point1.x, y1: point1.y, x2: point2.x, y2: point2.y, withRespectTo: .x)
                let angleY = isAngleOfDeviationGreaterThanFiveDegrees(x1: point1.x, y1: point1.y, x2: point2.x, y2: point2.y, withRespectTo: .y)
                
                
                
                if let point1_3D = convertBoundingBoxTo3D(point1), let point2_3D = convertBoundingBoxTo3D(point2) {
                    let distance3D = Double(calculateDistance(from: point1_3D, to: point2_3D) * 1000)
                    
                    print("distance:  \(distance3D)")
                    
                    if distance3D >= startDistance && distance3D <= endDistance {
                        if angleX <= rangeDegree || angleY <= rangeDegree {
                            context.move(to: point1)
                            context.addLine(to: point2)
                            
                            // Update the connection counts
                            connectionCounts[point1]! += 1
                            connectionCounts[point2]! += 1
                            
                            // Calculate midpoint for displaying distance
                            
                            let midpoint = CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
                            
                            let angle = min(angleX, angleY)
                            
                            displayDistanceLabel(at: midpoint, distance: "\(Int(distance3D)), \(Int(angle))°")
                        }
                    }
                } else {
                    print("Failed to get 3D coordinates for nails.")
                }
            }
        }
        
        context.strokePath()
    }
    
    
    
    
    
    //    func drawLinesThroughPoints(context: CGContext, points: [CGPoint]) {
    //        // Create and sort edges by their lengths
    //        let edges = createEdges(points: points).sorted { $0.2 < $1.2 }
    //
    //        // Dictionary to keep track of the number of connections for each point
    //        var connectionCounts = [CGPoint: Int]()
    //        var angleCounts = [CGPoint: Int]()
    //
    //        for point in points {
    //            connectionCounts[point] = 0
    //            angleCounts[point] = 0
    //        }
    //
    //        context.beginPath()
    //
    //        // Iterate over sorted edges and add them if they don't exceed the connection limit
    //        for edge in edges {
    //            let (point1, point2, distance) = edge
    //
    //            if connectionCounts[point1]! < 4 && connectionCounts[point2]! < 4 {
    //                let angleX = isAngleOfDeviationGreaterThanFiveDegrees(x1: point1.x, y1: point1.y, x2: point2.x, y2: point2.y, withRespectTo: .x)
    //                let angleY = isAngleOfDeviationGreaterThanFiveDegrees(x1: point1.x, y1: point1.y, x2: point2.x, y2: point2.y, withRespectTo: .y)
    //
    //                if angleX <= 30 || angleY <= 30 {
    //                    let point1Angles = angleCounts[point1]!
    //                    let point2Angles = angleCounts[point2]!
    //
    //                    if point1Angles < 2 && point2Angles < 2 {
    //                        // Draw the line
    //                        context.move(to: point1)
    //                        context.addLine(to: point2)
    //
    //                        // Update the connection and angle counts
    //                        connectionCounts[point1]! += 1
    //                        connectionCounts[point2]! += 1
    //                        angleCounts[point1]! += 1
    //                        angleCounts[point2]! += 1
    //
    //                        // Calculate midpoint for displaying distance
    //                        let midpoint = CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
    //
    //                        // Calculate the angle and distance (if needed, based on your requirements)
    //                        let angle = min(angleX, angleY)
    //
    //                        if isDistance3D {
    //                            if let point1_3D = convertBoundingBoxTo3D(point1), let point2_3D = convertBoundingBoxTo3D(point2) {
    //                                let distance3D = Double(calculateDistance(from: point1_3D, to: point2_3D) * 1000)
    //
    //                                if distance3D >= startDistance && distance3D <= endDistance {
    //                                    displayDistanceLabel(at: midpoint, distance: "\(Int(distance3D)), \(Int(angle))°")
    //                                }
    //                            } else {
    //                                print("Failed to get 3D coordinates for nails.")
    //                            }
    //                        }
    //                    }
    //                } else {
    //                    // Draw the line if the angles are greater than 30 degrees
    //                    context.move(to: point1)
    //                    context.addLine(to: point2)
    //
    //                    // Update the connection counts without updating the angle counts
    //                    connectionCounts[point1]! += 1
    //                    connectionCounts[point2]! += 1
    //
    //                    // Calculate midpoint for displaying distance
    //                    let midpoint = CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
    //
    //                    // Calculate the angle and distance (if needed, based on your requirements)
    //                    let angle = min(angleX, angleY)
    //
    //                    if isDistance3D {
    //                        if let point1_3D = convertBoundingBoxTo3D(point1), let point2_3D = convertBoundingBoxTo3D(point2) {
    //                            let distance3D = Double(calculateDistance(from: point1_3D, to: point2_3D) * 1000)
    //
    //                            if distance3D >= startDistance && distance3D <= endDistance {
    //                                displayDistanceLabel(at: midpoint, distance: "\(Int(distance3D)), \(Int(angle))°")
    //                            }
    //                        } else {
    //                            print("Failed to get 3D coordinates for nails.")
    //                        }
    //                    }
    //                }
    //            }
    //        }
    //
    //        context.strokePath()
    //    }
    //
    
    
    
    // Calculate angle of deviation
    func isAngleOfDeviationGreaterThanFiveDegrees(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, withRespectTo axis: Axis) -> CGFloat {
        let difference1: CGFloat
        let difference2: CGFloat
        
        switch axis {
        case .x:
            difference1 = abs(x2 - x1)
            difference2 = abs(y2 - y1)
        case .y:
            difference1 = abs(y2 - y1)
            difference2 = abs(x2 - x1)
        }
        
        let length = sqrt(difference1 * difference1 + difference2 * difference2)
        let cosTheta = difference1 / length
        let theta = acos(cosTheta)
        let thetaInDegrees = theta * 180.0 / .pi
        
        return thetaInDegrees
    }
    
    // Create edges for points
    func createEdges(points: [CGPoint]) -> [(CGPoint, CGPoint, CGFloat)] {
        var edges: [(CGPoint, CGPoint, CGFloat)] = []
        for i in 0..<points.count {
            for j in i+1..<points.count {
                let distance = hypot(points[i].x - points[j].x, points[i].y - points[j].y)
                edges.append((points[i], points[j], distance))
            }
        }
        return edges
    }
    
    // Calculate distance between two points
    func calculateDistanceBetweenPoints(point1: CGPoint, point2: CGPoint) -> CGFloat {
        let deltaX = point2.x - point1.x
        let deltaY = point2.y - point1.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    // Kruskal's algorithm for minimum spanning tree
    func kruskal(points: [CGPoint], edges: [(CGPoint, CGPoint, CGFloat)]) -> [(CGPoint, CGPoint)] {
        var parent = [Int](0..<points.count)
        var rank = [Int](repeating: 0, count: points.count)
        
        func find(_ x: Int) -> Int {
            if parent[x] != x {
                parent[x] = find(parent[x])
            }
            return parent[x]
        }
        
        func union(_ x: Int, _ y: Int) {
            let rootX = find(x)
            let rootY = find(y)
            if rootX != rootY {
                if rank[rootX] < rank[rootY] {
                    parent[rootX] = rootY
                } else if rank[rootX] > rank[rootY] {
                    parent[rootY] = rootX
                } else {
                    parent[rootY] = rootX
                    rank[rootX] += 1
                }
            }
        }
        
        let sortedEdges = edges.sorted { $0.2 < $1.2 }
        var mstEdges: [(CGPoint, CGPoint)] = []
        
        for edge in sortedEdges {
            let (point1, point2, _) = edge
            let index1 = points.firstIndex(of: point1)!
            let index2 = points.firstIndex(of: point2)!
            
            if find(index1) != find(index2) {
                mstEdges.append((point1, point2))
                union(index1, index2)
            }
        }
        
        return mstEdges
    }
}


// Extensions
extension VNRecognizedObjectObservation {
    var label: String? {
        return self.labels.first?.identifier
    }
}


extension CGRect {
    func toString(digit: Int, width: CGFloat, height: CGFloat) -> String {
        let xStr = String(format: "%.\(digit)f", origin.x)
        let yStr = String(format: "%.\(digit)f", origin.y)
        return "(\(xStr), \(yStr))"
    }
}


extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
    public static func == (lhs: CGPoint, rhs: CGPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}
