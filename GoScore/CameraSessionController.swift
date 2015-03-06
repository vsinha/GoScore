//
//  CameraSessionController.swift
//  GoScore
//
//  Created by Viraj Sinha on 2/27/15.
//  Copyright (c) 2015 WhitneyLand. All rights reserved.
//


import UIKit
import AVFoundation
import CoreMedia
import CoreImage


@objc protocol CameraSessionControllerDelegate {
    optional func cameraSessionDidOutputSampleBuffer(sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
}

class CameraSessionController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    var session: AVCaptureSession!
    var sessionQueue: dispatch_queue_t!
    var camera: AVCaptureDevice!
    var cameraInput: AVCaptureDeviceInput!
    var cameraOutput: AVCaptureVideoDataOutput!
    var stillImageOutput: AVCaptureStillImageOutput!
    var runtimeErrorHandlingObserver: AnyObject?
    
    var sessionDelegate: CameraSessionControllerDelegate?
    
    
    override init() {
        super.init()
        
        self.session = AVCaptureSession()
        
        // ensure that our app is allowed to use the camera
        self.authorizeCamera()
        
        // grab the (rear facing) camera
        self.configureCamera()
        
        //self.camera.addObserver(self, forKeyPath: "adjustingFocus", options: nil, context: nil)
        //self.camera.addObserver(self, forKeyPath: "adjustingExposure", options: nil, context: nil)
        //self.camera.addObserver(self, forKeyPath: "adjustingWhiteBalance", options: nil, context: nil)
        
        self.sessionQueue = dispatch_queue_create("CameraSessionController Session", DISPATCH_QUEUE_SERIAL)
        
        // dispatch sync will block until all actions are finished
        // this way, we prevent ourselves from starting the AVCaptureSession until after
        // the asynchronous configuriation steps have completed
        dispatch_sync(self.sessionQueue, {
            self.session.beginConfiguration()
            self.setSessionPreset()
            self.addVideoInput()
            self.addVideoOutput()
            self.addStillImageOutput()
            self.session.commitConfiguration()
        })
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        
        switch keyPath {
        case "adjustingFocus":
            println("adjustingFocus: \(self.camera.adjustingFocus)")
            self.checkIsAdjusting()
        case "adjustingExposure":
            println("adjustingExposure: \(self.camera.adjustingExposure)")
            self.checkIsAdjusting()
        case "adjustingExposure":
            println("adjustingWhiteBalance: \(self.camera.adjustingWhiteBalance)")
            self.checkIsAdjusting()
        default:
            break
        }
    }
    
    // call this any time the 3 attributes update, so we can see if we're looking
    // at a frame that the camera hardware has decided it's happy with
    func checkIsAdjusting() {
        //println("checking!")
        if (!self.camera.adjustingFocus &&
            !self.camera.adjustingWhiteBalance) {
                println("we have a winner!")
        }
    }
    
    
    func authorizeCamera() {
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: {
            (granted: Bool) -> Void in
            // If permission hasn't been granted, notify the user.
            if !granted {
                dispatch_async(dispatch_get_main_queue(), {
                    UIAlertView(
                        title: "Could not use camera!",
                        message: "This application does not have permission to use camera. Please update your privacy settings.",
                        delegate: self,
                        cancelButtonTitle: "OK").show()
                })
            }
        });
    }
    
    
    func configureCamera() {
        // initialize the camera
        self.camera = CameraSessionController.deviceWithMediaType(AVMediaTypeVideo, position: AVCaptureDevicePosition.Back)
        
        // Configure autofocus
        self.camera.lockForConfiguration(nil)
        self.camera.focusMode = .ContinuousAutoFocus
        self.camera.unlockForConfiguration()
    }
    
    
    func setFocusPoint(point: CGPoint) {
        println("setting autofocus point to (\(point.x), \(point.y))")
        self.camera.lockForConfiguration(nil)
        self.camera.focusPointOfInterest = point
        self.camera.unlockForConfiguration()
    }
    
    // static class function
    class func deviceWithMediaType(mediaType: String, position: AVCaptureDevicePosition) -> AVCaptureDevice {
        let devices = AVCaptureDevice.devicesWithMediaType(mediaType)
        var captureDevice: AVCaptureDevice = devices.first as AVCaptureDevice
        
        for object: AnyObject in devices {
            let device = object as AVCaptureDevice
            if device.position == position {
                captureDevice = device
                break
            }
        }
        
        return captureDevice
    }
    
    
    // get the highest quality video stream possible
    // TODO maybe if image processing performance differs on different devices 
    // we can try modify this based on the device...
    func setSessionPreset() {
//        self.session.sessionPreset = AVCaptureSessionPresetHigh
        self.session.sessionPreset = AVCaptureSessionPreset1280x720
    }


    // Setup rear facing input and add the feed to our AVCaptureSession
    func addVideoInput() -> Bool {
        var success: Bool = false
        var error: NSError?
        
        self.cameraInput = AVCaptureDeviceInput.deviceInputWithDevice(self.camera, error: &error) as AVCaptureDeviceInput
        if error == nil {
            if session.canAddInput(self.cameraInput) {
                self.session.addInput(self.cameraInput)
                success = true
            }
        }
        
        return success
    }

    
    // Setup capture output for the video device input
    func addVideoOutput() {
        var settings: [String: Int] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        self.cameraOutput = AVCaptureVideoDataOutput()
        self.cameraOutput.videoSettings = settings
        self.cameraOutput.alwaysDiscardsLateVideoFrames = true

        self.cameraOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
        
        if self.session.canAddOutput(self.cameraOutput) {
            self.session.addOutput(self.cameraOutput)
        }
    }
    
    
    func addStillImageOutput() {
        self.stillImageOutput = AVCaptureStillImageOutput()
        self.stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        
        /*
        self.stillImageOutput.
        println(self.stillImageOutput.availableImageDataCVPixelFormatTypes
        */
        println("image stabilization?: \(self.stillImageOutput.stillImageStabilizationSupported)")
        
        if self.session.canAddOutput(self.stillImageOutput) {
            self.session.addOutput(self.stillImageOutput)
        }
    }
    
    
    func startCamera() {
        dispatch_async(self.sessionQueue, {
            var weakSelf: CameraSessionController? = self
            self.runtimeErrorHandlingObserver = NSNotificationCenter.defaultCenter().addObserverForName(
                AVCaptureSessionRuntimeErrorNotification,
                object: self.sessionQueue,
                queue: nil,
                usingBlock: {
                    (note: NSNotification!) -> Void in
                    
                    let strongSelf: CameraSessionController = weakSelf!
                    
                    dispatch_async(strongSelf.sessionQueue, {
                        strongSelf.session.startRunning()
                    })
                })
        })
        self.session.startRunning()
    }
    
    
    func teardownCamera() {
        dispatch_async(self.sessionQueue, {
            self.session.stopRunning()
            NSNotificationCenter.defaultCenter().removeObserver(self.runtimeErrorHandlingObserver!)
        })
    }
    
    func focusAndExposeAtPoint(point: CGPoint) {
        dispatch_async(self.sessionQueue, {
            var device: AVCaptureDevice = self.cameraInput.device
            var error: NSErrorPointer!
            
            if device.lockForConfiguration(error) {
                if device.focusPointOfInterestSupported && device.isFocusModeSupported(AVCaptureFocusMode.AutoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = AVCaptureFocusMode.AutoFocus
                }
                
                if device.exposurePointOfInterestSupported && device.isExposureModeSupported(AVCaptureExposureMode.AutoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = AVCaptureExposureMode.AutoExpose
                }
                
                device.unlockForConfiguration()
            }
            else {
                // TODO: Log error.
            }
        })
    }
    
    
    func captureImage(completion:((image: UIImage?, error: NSError?) -> Void)?) {
        if completion == nil || self.stillImageOutput == nil{
            return
        }
        
        dispatch_async(self.sessionQueue, {
            
            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo), completionHandler: {
                (imageDataSampleBuffer: CMSampleBuffer?, error: NSError?) -> Void in
                if imageDataSampleBuffer == nil || error != nil {
                    completion!(image:nil, error:nil)
                }
                else if imageDataSampleBuffer != nil {
                    var imageData: NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer?)
                    var image: UIImage = UIImage(data: imageData)!
                    completion!(image:image, error:nil)
                }
            })
        })
    }
    
    
    // AVCaptureVideoDataOutputSampleBufferDelegate delegate method
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        self.sessionDelegate?.cameraSessionDidOutputSampleBuffer?(sampleBuffer, fromConnection:connection)
    }
}









