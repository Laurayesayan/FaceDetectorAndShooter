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
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title,
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK",
                                         style: .default) { _ in
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
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.borderWidth = 2
        shapeLayer.borderColor = #colorLiteral(red: 0.9849896891, green: 0.8375290671, blue: 0.3429784259, alpha: 0.7966074486)
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    fileprivate func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        pathLayer.sublayers = nil
        if animationCompleted {
            for observation in faces {
                let faceBox = VNImageRectForNormalizedRect(observation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
                let faceLayer = createRoundedRectLayerWithBounds(faceBox)

                animateShot(to: faceBox)
                pathLayer.addSublayer(faceLayer)
            }
        }
        CATransaction.commit()
    }

    fileprivate func animateShot(to faceBox: CGRect) {
        let bullet = UIImageView(image: UIImage(imageLiteralResourceName: "bullet"))
        bullet.frame = CGRect(origin: CGPoint.zero, size: bullet.image!.size)
        bullet.layer.anchorPoint = CGPoint(x: 1, y: 0)
        bullet.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height - bullet.image!.size.height)

        let convertedFaceBox = pathLayer.convert(faceBox, to: view.layer)
        view.addSubview(bullet)
        
        let distance = view.frame.size.width / min(faceBox.size.width, faceBox.size.height)
        let duration = Double(distance) * 0.3

        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: { [weak self] in
            bullet.layer.position = CGPoint(x: convertedFaceBox.midX, y: convertedFaceBox.midY)
            self!.animationCompleted = false
        }) { [weak self] (bool) in
            bullet.isHidden = true
            self!.animationCompleted = true
        }
    }
    
    func convertCoords(rect: CGRect) {
        
    }
}
