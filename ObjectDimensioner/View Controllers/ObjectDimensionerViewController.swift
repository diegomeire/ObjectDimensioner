//
//  ViewController.swift
//  ObjectDimensioner
//
//  Created by Diego Meire on 28/04/20.
//  Copyright © 2020 Diego Meire. All rights reserved.
//

import UIKit

class ObjectDimensionerViewController: UIViewController, OpenCVWrapperDelegate, UITextFieldDelegate, UITabBarDelegate, UIScrollViewDelegate {
    
    @IBOutlet weak var sliderMinBrightness: UISlider!
    @IBOutlet weak var sliderMaxBrightness: UISlider!
    
    @IBOutlet weak var sliderMinSaturation: UISlider!
    @IBOutlet weak var sliderMaxSaturation: UISlider!
    
    var colorsToFind = [UIColor]()
    
    @IBOutlet weak var thresholdSlider: UISlider!
    @IBOutlet weak var maxThresholdSlider: UISlider!
    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var trueMeasureWidth: UITextField!
    @IBOutlet weak var trueMeasureHeight: UITextField!
    @IBOutlet weak var widthLabel: UILabel!
    @IBOutlet weak var heightLabel: UILabel!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBOutlet weak var pixelsPerMetricWidthLabel: UILabel!
    @IBOutlet weak var pixelsPerMetricHeightLabel: UILabel!
    
    @IBOutlet weak var scrollViewTopConstraint : NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        thresholdSlider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        maxThresholdSlider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        sliderMinSaturation.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        sliderMaxSaturation.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        sliderMinBrightness.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        sliderMaxBrightness.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        
        trueMeasureWidth.delegate = self
        trueMeasureHeight.delegate = self
        
        sliderMinSaturation.value = UserDefaults.standard.float(forKey: "MinSaturation")
        sliderMaxSaturation.value = UserDefaults.standard.float(forKey: "MaxSaturation")
        sliderMinBrightness.value = UserDefaults.standard.float(forKey: "MinBrightness")
        sliderMaxBrightness.value = UserDefaults.standard.float(forKey: "MaxBrightness")
        
        OpenCVWrapper.shared()?.threshold = Int32( thresholdSlider.value )
        OpenCVWrapper.shared()?.maxThreshold = Int32( thresholdSlider.value )
        OpenCVWrapper.shared()?.minSaturation = CGFloat(sliderMinSaturation.value )
        OpenCVWrapper.shared()?.maxSaturation = CGFloat(sliderMaxSaturation.value )
        OpenCVWrapper.shared()?.minBrightness = CGFloat(sliderMinBrightness.value)
        OpenCVWrapper.shared()?.maxBrightness = CGFloat(sliderMaxBrightness.value)
        OpenCVWrapper.shared()?.calibrating = false
        
        scrollView.contentSize = CGSize(width: scrollView.bounds.width * 3, height: 200)
        scrollView.delegate = self
        scrollView.isPagingEnabled = true

    }
    
    
    @objc func valueChanged( sender: UISlider){
        if (sender.tag == 0){
            OpenCVWrapper.shared()?.threshold = Int32( sender.value)
            UserDefaults.standard.set(OpenCVWrapper.shared()?.threshold, forKey: "Threshold")
        }
        else
        if (sender.tag == 1){
            OpenCVWrapper.shared()?.maxThreshold = Int32(sender.value)
            UserDefaults.standard.set(OpenCVWrapper.shared()?.maxThreshold, forKey: "MaxThreshold")
        }
        else
        if (sender.tag == 2){
            OpenCVWrapper.shared()?.minSaturation = CGFloat(sender.value)
            UserDefaults.standard.set(Float(OpenCVWrapper.shared()!.minSaturation), forKey: "MinSaturation")
        }
        else
        if (sender.tag == 3){
            OpenCVWrapper.shared()?.maxSaturation = CGFloat(sender.value)
            UserDefaults.standard.set(Float(OpenCVWrapper.shared()!.maxSaturation), forKey: "MaxSaturation")
        }
        else
        if (sender.tag == 4){
            OpenCVWrapper.shared()?.minBrightness = CGFloat(sender.value)
            UserDefaults.standard.set(Float(OpenCVWrapper.shared()!.minBrightness), forKey: "MinBrightness")
        }
        else
        if (sender.tag == 5){
            OpenCVWrapper.shared()?.maxBrightness = CGFloat(sender.value)
            UserDefaults.standard.set(Float(OpenCVWrapper.shared()!.maxBrightness), forKey: "MaxBrightness")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        OpenCVWrapper.shared()?.createOpenCVVideoCamera(with: imageView)
        OpenCVWrapper.shared()?.delegate = self
        OpenCVWrapper.shared()?.startVideo()
        
        thresholdSlider.value = UserDefaults.standard.float(forKey: "Threshold")
        maxThresholdSlider.value = UserDefaults.standard.float(forKey: "MaxThreshold")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        scrollViewTopConstraint.constant = 0
        scrollView.layoutIfNeeded()
        textField.resignFirstResponder()
        
        return true
    }
    
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        scrollViewTopConstraint.constant = -100
        scrollView.layoutIfNeeded()
    }
    
    @IBAction func save(Sender: AnyObject){
        let objWidth = (trueMeasureWidth.text! as NSString).doubleValue
        let objHeight = (trueMeasureHeight.text! as NSString).doubleValue
        
        OpenCVWrapper.shared()?.saveObjectRealWidth(objWidth, andHeight: objHeight)
    }
    
    func widthChanged(_ width: Float) {
        DispatchQueue.main.async {
            self.widthLabel.text = String(width)
            self.pixelsPerMetricWidthLabel.text = String( format: "%3.3f", OpenCVWrapper.shared().pixelsPerMetricHorizontal)
        }
    }
    
    func heightChanged(_ height: Float) {
        DispatchQueue.main.async {
            self.heightLabel.text = String(height)
            self.pixelsPerMetricHeightLabel.text = String( format: "%3.3f", OpenCVWrapper.shared().pixelsPerMetricVertical)
        }
    }
    
    
    func pictureTaken(withColors colors: [Any]!) {}
    
    func calibrationStarted() {}
    
    func calibrationFinished() {}
    
    func patternFound() {}
    
    func patternNotFound() {}
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = round(scrollView.contentOffset.x/view.frame.width)
        pageControl.currentPage = Int(pageIndex)
    }
    
}

