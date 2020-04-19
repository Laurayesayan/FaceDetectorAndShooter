//
//  FaceDetectorViewController.swift
//  Vision_2_12
//
//  Created by Лаура Есаян on 16.04.2020.
//  Copyright © 2020 LY. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class FaceDetectorViewController: ViewController {
    private var sequenceHandler = VNSequenceRequestHandler()
    var animationCompleted = true
    
    var pathLayer: CALayer! = nil
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedFaces)
    
    override func setupAVCapture() {
        super.setupAVCapture()
        
        setupLayers()
        updateLayerGeometry()
        
        startCaptureSession()
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        do {
            try sequenceHandler.perform([self.faceDetectionRequest], on: pixelBuffer, orientation: exifOrientation)
        } catch {
            print(error)
        }
    }
    
    func setupLayers() {
        pathLayer = CALayer() // container layer that has all the renderings of the observations
        pathLayer.name = "DetectionOverlay"
        pathLayer.bounds = CGRect(x: 0.0,
                                  y: 0.0,
                                  width: bufferSize.width,
                                  height: bufferSize.height)
        pathLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(pathLayer)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        pathLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        pathLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func presentAlert(_ title: String, error: NSError) {
        // Always present alert on main thread.
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title,
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK",
                                         style: .default) { _ in
                                            // Do nothing -- simply dismiss alert.
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    fileprivate func handleDetectedFaces(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            self.presentAlert("Face Detection Error", error: nsError)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let drawLayer = self!.pathLayer,
                let results = request?.results as? [VNFaceObservation] else {
                    return
            }
            self!.draw(faces: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        
        return rect
    }
    
    fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
        // Create a new layer.
        let layer = CAShapeLayer()
        
        // Configure layer's appearance.
        layer.fillColor = nil // No fill to show boxed object
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 2
        
        // Vary the line color according to input.
        layer.borderColor = color.cgColor
        
        // Locate the layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        
        // Transform the layer to have same coordinate system as the imageView underneath it.
        layer.transform = CATransform3DMakeScale(1, -1, 1)
        
        return layer
    }
    
    fileprivate func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        pathLayer.sublayers = nil
        if animationCompleted {
            for observation in faces {
                let faceBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
                let faceLayer = shapeLayer(color: .yellow, frame: faceBox)

                animateShot(to: faceBox)
                pathLayer.addSublayer(faceLayer)
            }
        }
        CATransaction.commit()
    }

    fileprivate func animateShot(to faceBox: CGRect) {
        let bullet = UIImageView(image: UIImage(imageLiteralResourceName: "bullet"))
        bullet.frame = CGRect(origin: CGPoint.zero, size: bullet.image!.size)
        bullet.layer.anchorPoint = CGPoint(x: 0, y: 0)
        bullet.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height - bullet.image!.size.height)
//        bullet.transform = CGAffineTransform(scaleX: 1, y: -1)
        
        view.addSubview(bullet)
        
        let distance = view.frame.size.width / min(faceBox.size.width, faceBox.size.height)
        let duration = Double(distance) * 0.45
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: { [weak self] in
            bullet.center = CGPoint(x: faceBox.origin.y - faceBox.size.height / 2, y: faceBox.origin.x + faceBox.size.width / 2)
//            bullet.center = CGPoint(x: self!.view.frame.midX, y: self!.view.frame.midY)
//            bullet.center = CGPoint(x: faceBox.midY, y: faceBox.midX)
            self!.animationCompleted = false
        }) { [weak self] (F) in
            bullet.isHidden = true
            self!.animationCompleted = true
        }
    }
}
