//
//  MainViewController.swift
//
//  Created by Viraj Sinha on 2/27/15
//  Copyright (c) 2015 Viraj Sinha. All rights reserved.
//

import UIKit
import AVFoundation


class MainViewController: UIViewController, CameraSessionControllerDelegate {
    
    var selectedImage : UIImage!
    
    
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var staticView: UIImageView!
    
    //let captureSession = AVCaptureSession()
    //let stillImageoutput: AVCaptureStillImageOutput?
    
    var cameraSessionController: CameraSessionController!
    var previewLayer: AVCaptureVideoPreviewLayer!

    
    // Lazily grab the camera
    lazy var backCamera: AVCaptureDevice? = {
        // Loop through all the capture devices on this phone
        for device in AVCaptureDevice.devices() {
            // Make sure this particular device supports video
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == AVCaptureDevicePosition.Back) {
                    return (device as? AVCaptureDevice)
                }
            }
        }
        return nil
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.cameraView.frame = self.view.frame
        //self.cameraView.hidden = true

        
        // Initialize the camera...
        //captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        cameraSessionController = CameraSessionController()
        cameraSessionController.sessionDelegate = self
        
        //self.setupPreviewLayer()
        
        self.staticView.bounds = self.view.bounds
        self.staticView.frame = self.view.frame
        self.view.bringSubviewToFront(self.staticView)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        cameraSessionController.startCamera()
    }
    
    func setupPreviewLayer() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.cameraSessionController.session)
        self.previewLayer.bounds = self.cameraView.bounds
        self.previewLayer.frame = self.cameraView.frame
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.previewLayer.backgroundColor = UIColor.blackColor().CGColor // UNNECESSARY PROBABLY
        self.view.layer.addSublayer(self.previewLayer)
    }
    
    
    // Delegate Method
    func cameraSessionDidOutputSampleBuffer(sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        //println("cameraSessionDidOutputSampleBuffer")
        
        /*if connection.supportsVideoOrientation {
            connection.videoOrientation = AVCaptureVideoOrientation.Portrait
        }
        
        if connection.supportsVideoMirroring {
            connection.videoMirrored = true
        }
        */
        
        // cameraView.updateTextureFromSampleBuffer(sampleBuffer)
    }
    
    // set autofocus to touch point
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        let anyTouch = touches.anyObject() as UITouch
        //self.cameraSessionController.setFocusPoint(anyTouch.locationInView(self.view))
        
        self.cameraSessionController.captureImage(self.handleImageCapture)
    
    }
    
    func handleImageCapture(capturedImage: UIImage?, error: NSError?) -> Void {
        println("captured image!")
        
        if capturedImage == nil || error != nil {
            println("there was an error handling the captured image")
            return
        }
        
        
        let processedImage = CVWrapper.processImageWithOpenCV(capturedImage)
        
        var rotatedProcessedImage = UIImage(CGImage: processedImage.CGImage, scale: CGFloat(1.0),orientation: UIImageOrientation.Right)
        
        self.staticView.image = rotatedProcessedImage
    }
}

