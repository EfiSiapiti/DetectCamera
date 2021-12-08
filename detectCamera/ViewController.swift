//
//  ViewController.swift
//  detectCamera
//
//  Created by Έφη Σιαπιτή on 27/07/2021.
//

import Cocoa
import CoreMediaIO
import AVFoundation

//capture session for the camera
private var captSession: AVCaptureSession!
//this is the physical device
private var device: AVCaptureDevice!
//this is the thread's current runloop that allows the changes to be detected and times the interval between the loops. If this object was not implemented, the changes in the camera access are not detected.
let runLoop = RunLoop.current;
//the process ID
let pid = getpid()
class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate,
                      AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if ((error?.localizedDescription) == nil) {
            print("file is finished")
        }
        else
        {
            print("Error with file")
        }
    }
    //main function of the application that runs after view is loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        var count=0;
        print("To reset authorization press 1")
        print("To start detecting for the camera and save the stream when it is on press 2")
        let ans:Int? = Int(readLine() ?? " ")
        switch ans {
        case 1:
            resetAuthorization()
        case 2:
        //busy loop that keeps looping every 2 seconds
        while(true) {
        if (cameraOn()) {
            print ("it is on");
        //switch statement that checks the current authorization status and acts accordingly
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            //camera has been previously authorized
            case .authorized:
                self.setupStartCamera(_input:count)
                count+=1
            //authorization status not derermined
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.setupStartCamera(_input:count)
                            count+=1
                        }
                    }
                    else {
                        print ("No access given")
                    }
                }
            //authorization status has been denied
            case .denied:
                print("The camera access has been denied")
            //camera has been restricted
            case .restricted:
                print("access restricted")
            //this is for the default case
            @unknown default:
                return
    }
    }
        else {
        print("not on");
        
    }
            //delay of 2 seconds
            let interval=Date().addingTimeInterval(2)
            runLoop.run(until: interval)
        }
        default:
            print("Invalid choice, try again")
        }
    }
    //function that returns true if the hardware of camera is turned on
    public func cameraOn() -> Bool {
        //gets the camera id from the function below
        guard let cam = findCamId() else {
            return false
        }
        //address for property
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
        //variable to store the answer
        var isCamOn = false
        //data variables initialised to 0
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        //variable containing an OSStatus indicating success or failure.
        var ans = CMIOObjectGetPropertyDataSize(cam, &prop, 0, nil, &dataSize)
        //querie to check, if there is no hardware error, if the camera is on or off
        if ans == OSStatus(kCMIOHardwareNoError) {
            if let data = malloc(Int(dataSize)) {
                ans = CMIOObjectGetPropertyData(cam, &prop, 0, nil, dataSize, &dataUsed, data)
                let on = data.assumingMemoryBound(to: UInt8.self)
                isCamOn = on.pointee != 0
            }
        }
        return isCamOn
    }
    //function that will return the camera id
    private func findCamId() -> CMIOObjectID? {
        //address for property
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
        //data variables initialised to 0
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        //variable containing an OSStatus indicating success or failure.
        var ans = CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, &dataSize)

        var devices: UnsafeMutableRawPointer?
        repeat {
            //makes pointer point to nil
            if devices != nil {
                free(devices)
                devices = nil
            }
            //devices pointer gets allocated the dataSize memory position
            devices = malloc(Int(dataSize))
            //get the data of the given property and places it in the provided buffer(devices)
            ans = CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, dataSize, &dataUsed, devices)
        } while ans == OSStatus(kCMIOHardwareBadPropertySizeError)//loop stops when ans is not error
        var cameraId: CMIOObjectID?
        if let devices = devices {
           for offset in stride(from: 0, to: dataSize, by: MemoryLayout<CMIOObjectID>.size) {
                let current = devices.advanced(by: Int(offset)).assumingMemoryBound(to: CMIOObjectID.self)
                //pointee accesses the instance referenced by pointer
        cameraId = current.pointee
           }
        }
        free(devices)
        return cameraId;
    }
    //function that opens and uses the CLI
    public func useShell(_input:String)
   {
            let task = Process()
            task.arguments = ["-c", _input]
            task.launchPath = "/bin/zsh"
            task.launch()
            task.waitUntilExit()
   }
    //function that uses the above function to reset all camera authorizations
   public func resetAuthorization()
   {
    useShell(_input: "tccutil reset Camera")
   }

}
private extension ViewController {
    //setups the camera and session starts
    func setupStartCamera(_input:Int) {
        //session is initiated
        captSession = AVCaptureSession()
        guard let session = captSession else { return }
        session.sessionPreset=AVCaptureSession.Preset.low;
        //discovery session is created to find all the devices with type the parameters specified
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        //for all devices found in the discovery session
        for devices in discoverySession.devices {
          guard devices.hasMediaType(.video) else { return }
        
            //create video input and add it to the session
            do {
                let input = try AVCaptureDeviceInput(device: devices)
                    captSession?.addInput(input)
           } catch {
                print(error.localizedDescription)
            }
        }
        //create video output and add it to the session
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferDelegate"))
        let fileOut=AVCaptureMovieFileOutput()
        captSession?.addOutput(videoOutput)
        captSession?.addOutput(fileOut)
        //checks if the capure session is running, and if not it starts running
        guard let captSession = captSession, !captSession.isRunning else { return }
        captSession.startRunning()
        let path=FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let number=String(_input)
        let fileURL=path[0].appendingPathComponent(number+" output.mov")
        try? FileManager.default.removeItem(at: fileURL)
        fileOut.startRecording(to: fileURL, recordingDelegate: self)
        //wait 9 seconds
        let interval=Date().addingTimeInterval(9)
        runLoop.run(until: interval)
        fileOut.stopRecording()
        captSession.stopRunning()
    }
}
