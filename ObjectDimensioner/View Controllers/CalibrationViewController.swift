//
//  CalibrationViewController.swift
//  ObjectDimensioner
//
//  Created by Diego Meire on 02/05/20.
//  Copyright © 2020 Diego Meire. All rights reserved.
//

import Foundation
import UIKit

class CalibrationViewController: UIViewController, OpenCVWrapperDelegate {

    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var calibrationButton: UIButton!
    
    @IBOutlet weak var nextButton: UIBarButtonItem!
    
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {

    }
    
    var startedCalibration = false
    
    override func viewWillAppear(_ animated: Bool) {
        OpenCVWrapper.shared()?.createOpenCVVideoCamera(with: imageView)
        OpenCVWrapper.shared()?.calibrating = true
        OpenCVWrapper.shared()?.delegate = self
        OpenCVWrapper.shared()?.startVideo()
        
        nextButton.isEnabled = UserDefaults.standard.bool(forKey: "calibrated")
        
        if (nextButton.isEnabled){
            statusLabel.text = "Calibrated"
        }
        else{
            statusLabel.text = "Not calibrated"
        }
    }
    
    
    func widthChanged(_ width: Float) {
        
    }
    
    func heightChanged(_ height: Float) {
        
    }
    
    func pictureTaken(withColors colors: [Any]!) {
        
    }
    
    func patternFound() {
        DispatchQueue.main.async {
            if (self.startedCalibration){
                self.statusLabel.text = "Pattern found. Keep it up"
            }
        }
    }
    
    func patternNotFound() {
        DispatchQueue.main.async {
            if (self.startedCalibration){
                self.statusLabel.text = "Pattern not found. Point to the pattern"
            }
        }
    }
    
    func calibrationStarted() {
        DispatchQueue.main.async {
            self.calibrationButton.isEnabled = false
            self.calibrationButton.setTitle("Calibrating...", for: UIControl.State.disabled)
            self.nextButton.isEnabled = false
            self.startedCalibration = true
        }
       
    }
    
    func calibrationFinished() {

        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Alert", message: "Calibration finished", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                  switch action.style{
                  case .default:
                        print("default")

                  case .cancel:
                        print("cancel")

                  case .destructive:
                        print("destructive")
            }}))
            self.present(alert, animated: true, completion: nil)
            self.startedCalibration = false
            self.calibrationButton.isEnabled = true
            self.nextButton.isEnabled = true
            UserDefaults.standard.set(true, forKey: "calibrated")
            self.statusLabel.text = "Calibrated"
        }
        
    }
    
    @IBAction func startCalibrationPressed(){
        OpenCVWrapper.shared()?.startCalibration()
        
    }
    
}
