//
//  OpenCVWrapper.m
//  ObjectDimensioner
//
//  Created by Diego Meire on 31/07/19.
//  Copyright © 2019 Diege Miere. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "OpenCVWrapper.h"
// OpenCV
#import <opencv2/calib3d.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/videoio/cap_ios.h>

#import <CoreMedia/CoreMedia.h>

#import "opencv2/core/core_c.h"
#include "opencv2/saliency.hpp"

#include <cctype>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define CLAMP(x, low, high)  (((x) > (high)) ? (high) : (((x) < (low)) ? (low) : (x)))

using namespace std;
using namespace cv;
using namespace saliency;

@interface OpenCVWrapper() <CvVideoCameraDelegate, CvPhotoCameraDelegate>

@end

///***************************************************
/// Calibrator class
class Calibrator
{
    public:
        OpenCVWrapper *wrapper;
        cv::Mat cameraMatrix, distCoeffs;
        Calibrator(std::string outputPath, OpenCVWrapper *wrapperSender);
        int processFrame(cv::Mat frame);
        void startCapturing();
    private:
        enum { DETECTION = 0, CAPTURING = 1, CALIBRATED = 2 };
        enum Pattern { CHESSBOARD, CIRCLES_GRID, ASYMMETRIC_CIRCLES_GRID };
        
        void calcChessboardCorners(cv::Size boardSize, float squareSize, std::vector<cv::Point3f>& corners, Pattern patternType = CHESSBOARD);
        bool runCalibration( std::vector<std::vector<cv::Point2f> > imagePoints,
                            cv::Size imageSize, cv::Size boardSize, Pattern patternType,
                            float squareSize, float aspectRatio,
                            int flags, cv::Mat& cameraMatrix, cv::Mat& distCoeffs,
                            std::vector<cv::Mat>& rvecs, std::vector<cv::Mat>& tvecs,
                            std::vector<float>& reprojErrs,
                            double& totalAvgErr);
        bool runAndSave(const std::vector<std::vector<cv::Point2f> >& imagePoints,
                        cv::Size imageSize, cv::Size boardSize, Pattern patternType, float squareSize,
                        float aspectRatio, int flags, cv::Mat& cameraMatrix,
                        cv::Mat& distCoeffs, bool writeExtrinsics, bool writePoints );
        void saveCameraParams(cv::Size imageSize, cv::Size boardSize,
                              float squareSize, float aspectRatio, int flags,
                              const cv::Mat& cameraMatrix, const cv::Mat& distCoeffs,
                              const std::vector<cv::Mat>& rvecs, const std::vector<cv::Mat>& tvecs,
                              const std::vector<float>& reprojErrs,
                              const std::vector<std::vector<cv::Point2f> >& imagePoints,
                              double totalAvgErr );
        std::string outputPath;
        float squareSize;
        float aspectRatio;
        cv::Size boardSize, imageSize;
        Pattern pattern;
        bool writeExtrinsics, writePoints, undistortImage, flipVertical;
        int mode, i, nframes, flags, delay;
        
        std::vector<std::vector<cv::Point2f> > imagePoints;
        clock_t prevTimestamp;
       
};
///***************************************************


///***************************************************
@implementation OpenCVWrapper {
    
    CvVideoCamera * videoCamera;
    
    CvPhotoCamera * photoCamera;
    
    cv::Mat background;
    
    cv::dnn::Net net;
    
    cv::Mat processingImage;
    
    NSMutableArray *colorsToFind;
    
    bool isCapturingBackground;
    
    Calibrator * calibrator;
    
}


@synthesize threshold    = _threshold;
@synthesize maxThreshold = _maxThreshold;
@synthesize pixelsPerMetricHorizontal = _pixelsPerMetricHorizontal;
@synthesize pixelsPerMetricVertical = _pixelsPerMetricVertical;
@synthesize width   = _width;
@synthesize height  = _height;
@synthesize widthInPixels = _widthInPixels;
@synthesize heightInPixels = _heightInPixels;

@synthesize numberOfMeanColors = _numberOfMeanColors;
@synthesize minBrightness = _minBrightness;
@synthesize maxBrightness = _maxBrightness;
@synthesize minSaturation = _minSaturation;
@synthesize maxSaturation = _maxSaturation;

@synthesize objectWidth  = _objectWidth;
@synthesize objectHeight = _objectHeight;

@synthesize calibrating  = _calibrating;

///**************************************
- (instancetype)init {
    self = [super init];
    colorsToFind = [[NSMutableArray alloc]init];
    
    // Instantiating the calibrator
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    NSString *filePath = [directory stringByAppendingPathComponent:[NSString stringWithUTF8String:"camera_parameter.yml"]];
    calibrator = new Calibrator([filePath UTF8String], self);
    cout << calibrator->cameraMatrix << endl;
    
    // Load the camera matrix from the user defaults - in case it has been calibrated before
    NSArray *cameraMatrixArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"camMatrix"];
    
    calibrator->cameraMatrix =  cv::Mat::eye(3, 3, CV_64F);
    int col = 0;
    int row = 0;
    for (int i = 0; i < cameraMatrixArray.count; i ++){
        NSNumber *number = [cameraMatrixArray objectAtIndex:i];
        calibrator->cameraMatrix.at<double>(row,col) = number.doubleValue;
        cout << number.doubleValue << endl;
        if (col + 1 < 3){
            col++;
        }
        else{
            col = 0;
            row++;
        }
    }
    
    /// Load the distance coefficients from the user defaults - in case it has been calibrated before
    NSArray *diffCoefsArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"distCoeffs"];
    calibrator->distCoeffs =  cv::Mat::eye(5, 1, CV_64F);
    for (int i = 0; i < diffCoefsArray.count; i ++){
        NSNumber *number = [diffCoefsArray objectAtIndex:i];
        calibrator->distCoeffs.at<double>(0,i) = number.doubleValue;
    }
    
    _pixelsPerMetricHorizontal = 0;
    _pixelsPerMetricVertical = 0;
    
    return self;
}
///**************************************



///**************************************
+ (instancetype)shared
{
    static OpenCVWrapper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OpenCVWrapper alloc] init];
        // Loading the the pixels per metric from user defaults
        sharedInstance.pixelsPerMetricHorizontal = [[NSUserDefaults standardUserDefaults] doubleForKey:@"pixelsPerMetricHorizontal"];
        sharedInstance.pixelsPerMetricVertical   = [[NSUserDefaults standardUserDefaults] doubleForKey:@"pixelsPerMetricVertical"];
        sharedInstance.objectWidth               = [[NSUserDefaults standardUserDefaults] doubleForKey:@"objectWidth"];
        sharedInstance.objectHeight              = [[NSUserDefaults standardUserDefaults] doubleForKey:@"objectHeight"];
    });
    
    return sharedInstance;
}
///**************************************



///**************************************
- (void) createOpenCVVideoCameraWithImageView:(UIImageView *)imageView {
    
    videoCamera = [[CvVideoCamera alloc] initWithParentView:imageView];
    videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack; // Use the back camera
    videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait; // Ensure proper orientation
    videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetPhoto;
    videoCamera.rotateVideo = NO; // Ensure proper orientation
    videoCamera.defaultFPS = 30; // How often 'processImage' is called, adjust based on the amount/complexity of images
    videoCamera.delegate = self;
    
    isCapturingBackground = false;
    
}
///**************************************



///**************************************
- (void) createOpenCVPhotoCameraWithImageView:(UIImageView *)imageView {
    photoCamera = [[CvPhotoCamera alloc] initWithParentView:imageView];
    photoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack; // Use the back camera
    photoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait; // Ensure proper orientation
    photoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetPhoto;
    photoCamera.defaultFPS = 30; // How often 'processImage' is called, adjust based on the amount/complexity of images
    photoCamera.delegate = self;
    [photoCamera unlockFocus];
}
///**************************************




///**************************************
- (void) getBackground {
    isCapturingBackground = true;
}
///**************************************

///**************************************
- (void) clearColorsToFind
{
    [colorsToFind removeAllObjects];
}
///**************************************


///**************************************
- (void) addColorToFind:(UIColor*)color{
    [colorsToFind addObject:color];
}
///**************************************


///**************************************
bool compareContourAreas ( std::vector<cv::Point> contour1, std::vector<cv::Point> contour2 ) {
    double i = fabs( contourArea(cv::Mat(contour1)) );
    double j = fabs( contourArea(cv::Mat(contour2)) );
    return ( i < j );
}
///**************************************


///**************************************
float euclideanDist(cv::Point& p, cv::Point& q) {
    cv::Point diff = p - q;
    return cv::sqrt(diff.x*diff.x + diff.y*diff.y);
}
///**************************************



///**************************************
- (void) saveObjectRealWidth:(double)objectWidth andHeight:(double)objectHeight{
    if (objectWidth > 0){
        _objectWidth = objectWidth;
        [[NSUserDefaults standardUserDefaults] setDouble:_objectWidth forKey:@"objectWidth"];
    }
    
    if (objectHeight > 0){
        _objectHeight = objectHeight;
        [[NSUserDefaults standardUserDefaults] setDouble:_objectHeight forKey:@"objectHeight"];
    }
}
///**************************************


///**************************************
/// Here I replace the colors in colorsToFind with white
-(void) chromaKeyImage:(cv::Mat &)img {
    
    //
    cv::copyTo(img, background, cv::Mat());

    background = cv::Scalar(255, 255, 255, 255);
    
    cv::Mat hsv;
    cv::cvtColor(img, img, cv::COLOR_BGRA2BGR);
    cv::cvtColor(img, hsv, cv::COLOR_RGB2HSV);
    
    cv::Mat mask1, mask2;
    
    for (int i = 0; i < colorsToFind.count; i ++){
        
        cv::Mat auxMask;
        
        UIColor *color = colorsToFind[i];
        CGFloat hue;
        CGFloat saturation;
        CGFloat brightness;
        CGFloat margin;
        [color getHue:&hue
           saturation:&saturation
           brightness:&brightness
                alpha:nil];
        
        hue = hue * 180;
        saturation = saturation * 255;
        brightness = brightness * 255;
        
        double minSaturation = 0;
        double maxSaturation = 0;
        
        double minBrightness = 0;
        double maxBrightness = 0;
        
        if (_fullColorRange){
            minSaturation = 50;
            maxSaturation = 255;
            maxBrightness = 255;
        }
        else{
            minSaturation = saturation * 0.3;
            maxSaturation = saturation * 0.7;
            minBrightness = brightness * 0.3;
            maxBrightness = brightness * 0.7;
        }
        
        margin = 25;
        
        if (i == 0){
            cv::inRange( hsv,
                        cv::Scalar( CLAMP( hue - margin, 0, hue - margin ),
                                    _minSaturation, //( saturation * 0.1),
                                    _minBrightness),//( brightness * 0.1)),
                        cv::Scalar( CLAMP( hue + margin, hue + margin, 180 ),
                                    _maxSaturation,//( saturation * 1.5),
                                    _maxBrightness),//( brightness * 1.5)),
                        mask1);
        }
        else{
           cv::inRange( hsv,
                        cv::Scalar( CLAMP( hue - margin, 0, hue - margin),
                                   _minSaturation,//( saturation * 0.1),
                                   _minBrightness),//( brightness * 0.1)),//_value - _valueOffset),
                        cv::Scalar( CLAMP( hue + margin, hue + margin, 180 ),
                                   _maxSaturation, //( saturation * 1.5),
                                   _maxBrightness),//( brightness * 1.5)),
                        auxMask);
        
            mask1 = mask1 + auxMask;
        }
    }

    cv::Mat kernel = cv::Mat::ones(3,3, CV_32F);
    cv::morphologyEx(mask1,mask1,cv::MORPH_OPEN,kernel);
    cv::morphologyEx(mask1,mask1,cv::MORPH_DILATE,kernel);
    
    /// creating an inverted mask to segment out the cloth from the frame
    cv::bitwise_not(mask1,mask2);
    cv::Mat res1, res2, final_output;
    
    /// Segmenting the cloth out of the frame using bitwise and with the inverted mask
    cv::bitwise_and(img, img, res1, mask2);
    
    /// creating image showing static background frame pixels only for the masked region
    bitwise_and(background, background, res2, mask1 );
    
    /// Generating the final augmented output.
    addWeighted(res1,1,res2,1,0,final_output);
    
    cv::copyTo(final_output, img, cv::Mat());


    
}
///**************************************



///**************************************
- (void)processImage:(cv::Mat &)frame {
    
    if (!_calibrating){
    
       cv::Mat img;
       if (calibrator->cameraMatrix.size().area() > 0){
            cv::Mat aux;
            /// Here I undistort the image using the camera matrix and distance coeffs
            undistort(frame, aux, calibrator->cameraMatrix, calibrator->distCoeffs);
            cv::Rect roi = cv::Rect( frame.cols * 0.15, frame.rows * 0.15, aux.cols * 0.7, aux.rows * 0.7);
            cvtColor(aux, aux, COLOR_RGBA2BGR);
            cv::Mat temp (aux, roi);
            copyTo(temp, img, cv::Mat());
       }
       else{
            cv::Rect roi = cv::Rect(10, 10, frame.rows - 20, frame.cols - 20);
            cv::Mat img = frame(roi);
            copyTo(frame, img, cv::Mat());
       }
        
       [self chromaKeyImage:img];
        
       Mat src;
       Mat src_gray;
       int thresh = _threshold;
       int max_thresh = _maxThreshold;
       RNG rng (12345);

       Mat threshold_output;
       vector<vector<cv::Point>> contours;
       vector<Vec4i> hierarchy;

       int largest_object_area = 0;
       int largest_object_contour_index = 0;
       int largest_reference_area = 0;
       int largest_reference_contour_index = 0;
        
       cv::Rect bounding_rect;
       
       cvtColor(img, src_gray, cv::COLOR_BGR2GRAY); //produce out2, a one-channel image (CV_BUC1)
       cv::blur(src_gray, src_gray, cv::Size(5,5));
       
       threshold( src_gray,
                  threshold_output,
                  thresh,
                  max_thresh,
                  cv::THRESH_BINARY_INV);

       findContours( threshold_output,
                     contours,
                     hierarchy,
                     cv::RETR_EXTERNAL,
                     cv::CHAIN_APPROX_SIMPLE,
                     cv::Point(0,0));
       
       //Find the rotated rectangles
       vector<RotatedRect> minRect(contours.size());

       for(int i=0; i<contours.size(); i++)
       {
           minRect[i] = minAreaRect(Mat(contours[i]));
       }

       //Draw contours + rotated rectangles + ellipses
       Mat drawing = Mat::zeros(threshold_output.size(), CV_8UC3);
       
       if (contours.size() > 0 ){
          for (int i = 0; i < contours.size(); i++)
          {
               double area = contourArea( contours[i] );  //  Find the area of contour
               cv::Rect rect = boundingRect(contours[i]);
               if (rect.x > img.cols / 2){
                   if( area > largest_object_area )
                   {
                       largest_object_area = area;
                       largest_object_contour_index = i;               //Store the index of largest contour
                   }
               }
               else{
                   if( area > largest_object_area )
                   {
                       largest_reference_area = area;
                       largest_reference_contour_index = i;               //Store the index of largest contour
                   }
               }
          }
       
          drawContours( img, contours, largest_reference_contour_index, Scalar( 255, 0, 0 ), 1 );
          Point2f rect_reference_points[4]; minRect[largest_reference_contour_index].points(rect_reference_points);
          for(int j=0; j<4; j++){
              line(img, rect_reference_points[j], rect_reference_points[(j+1)%4], Scalar( 255, 0, 0 ), 2);
              cv::Point p1 = cv::Point( rect_reference_points[j].x, rect_reference_points[j].y );
              cv::Point p2 = cv::Point( rect_reference_points[(j+1)%4].x, rect_reference_points[(j+1)%4].y );
              
              float distance = euclideanDist(p1, p2);
              cv::Point midPoint = cv::Point( ( p1.x + p2.x ) / 2, ( p1.y + p2.y ) / 2 );

              if ( abs(p2.y - p1.y) > abs(p2.x - p1.x) ){
                  _heightInPixels = distance;
                  _pixelsPerMetricVertical = _heightInPixels / _objectHeight;
                  cv::putText(img, cv::format("%3.0f", distance), midPoint, cv:: FONT_HERSHEY_PLAIN, 3, Scalar( 255, 0, 0 ), 2);
              }
              else{
                  _widthInPixels = distance;
                  _pixelsPerMetricHorizontal = _widthInPixels / _objectWidth;
                  cv::putText(img, cv::format("%3.0f", distance), midPoint, cv:: FONT_HERSHEY_PLAIN, 3, Scalar( 255, 0, 0 ), 2);
              }
              
          }
       
       
          drawContours( img, contours, largest_object_contour_index, Scalar( 0, 0, 255 ), 1 );
          Point2f rect_obj_points[4]; minRect[largest_object_contour_index].points(rect_obj_points);
          for(int j=0; j<4; j++){
              line(img, rect_obj_points[j], rect_obj_points[(j+1)%4], Scalar( 0, 0, 255 ), 2);
              cv::Point p1 = cv::Point( rect_obj_points[j].x, rect_obj_points[j].y );
              cv::Point p2 = cv::Point( rect_obj_points[(j+1)%4].x, rect_obj_points[(j+1)%4].y );
              
              float distance = euclideanDist(p1, p2);
              cv::Point midPoint = cv::Point( ( p1.x + p2.x ) / 2, ( p1.y + p2.y ) / 2 );
              
              if ( abs(p2.y - p1.y) > abs(p2.x - p1.x) ){
                  if (_pixelsPerMetricVertical > 0){
                      _height = cvRound(distance) / _pixelsPerMetricVertical;
                      [self.delegate heightChanged:_height];
                  }
              }
              else{
                  if (_pixelsPerMetricHorizontal > 0){
                      _width = cvRound(distance) / _pixelsPerMetricHorizontal;
                      [self.delegate widthChanged:_width];
                  }
              }
              cv::putText(img, cv::format("%3.0f", distance), midPoint, cv:: FONT_HERSHEY_PLAIN, 3, Scalar( 0, 0, 255 ), 2);
          }
       }
        copyTo(img, frame, cv::Mat());
    }
    else {
        calibrator->processFrame(frame);
    }
    
   
}
///**************************************






///**************************************
- (void) photoCamera:(CvPhotoCamera *)photoCamera capturedImage:(UIImage *)image{
    
    cv::Mat src;
    
    UIImage *rotatedImage = [self fixOrientationForImage:image];
    
    UIImageToMat(rotatedImage, processingImage, false);
    
    cv::cvtColor(processingImage, processingImage, cv::COLOR_RGBA2RGB); // Converts matrix to 4 channels and save into gtpl variable.
    
    cv::Mat resized;
    cv::resize(processingImage, resized, cv::Size(300,300));
    
    fastNlMeansDenoisingColored( resized, resized, 3, 3, 7, 21);
    
    NSArray *colors = [self getColors];
    
    [self.delegate pictureTakenWithColors:colors];
    
}
///**************************************


///**************************************
- (void)photoCameraCancel:(CvPhotoCamera *)photoCamera {
    
}
///**************************************


///**************************************
- (void) takePicture{
    [photoCamera takePicture];
}
///**************************************




///**************************************
- (UIImage *)fixOrientationForImage:(UIImage*)neededImage {
    
    // No-op if the orientation is already correct
    if (neededImage.imageOrientation == UIImageOrientationUp) return neededImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (neededImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, neededImage.size.width, neededImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, neededImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, neededImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (neededImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, neededImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, neededImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, neededImage.size.width, neededImage.size.height,
                                             CGImageGetBitsPerComponent(neededImage.CGImage), 0,
                                             CGImageGetColorSpace(neededImage.CGImage),
                                             CGImageGetBitmapInfo(neededImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (neededImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,neededImage.size.height,neededImage.size.width), neededImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,neededImage.size.width,neededImage.size.height), neededImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}
///**************************************




///**************************************
- (NSArray*) getColorsForImage:(UIImage *)image{
    
    cv::Mat src;
    
    UIImage *rotatedImage = [self fixOrientationForImage:image];
    
    UIImageToMat(rotatedImage, processingImage, false);
    
    processingImage = [self enhanceColors:processingImage];
    
    cv::cvtColor(processingImage, processingImage, cv::COLOR_RGBA2BGRA);
    
    return [self getColors];
}
///**************************************


///**************************************
- (cv::Mat) enhanceColors:(cv::Mat) image {
    
    double alpha = 1.2; /* < Simple contrast control */
    int beta = 0.2;       /* < Simple brightness control */
    
    for( int y = 0; y < image.rows; y++ ) {
        for( int x = 0; x < image.cols; x++ ) {
            for( int c = 0; c < 3; c++ ) {
                image.at<cv::Vec3b>(y,x)[c] = cv::saturate_cast<uchar>( alpha*( image.at<cv::Vec3b>(y,x)[c] ) + beta );
            }
        }
    }
    
    
    return image;
}
///**************************************



///**************************************
- (cv::Mat) getSaliency:(cv::Mat) img{
    
    
    cv::Mat grayCroppedImage;
    cvtColor(img, grayCroppedImage, cv::COLOR_RGB2GRAY );
    
    
    Ptr<Saliency> saliencyAlgorithm;
    Mat saliencyMap;
    Mat binaryMap;
    saliencyAlgorithm = StaticSaliencySpectralResidual::create();
    if( saliencyAlgorithm->computeSaliency( grayCroppedImage, saliencyMap ) )
    {
        StaticSaliencySpectralResidual spec;
        spec.computeBinaryMap( saliencyMap, binaryMap );
    }
    
    for( int y = 0; y < img.rows; y++ ) {
        for( int x = 0; x < img.cols; x++ ){
            for( int z = 0; z < 3; z++){
                if (binaryMap.at<uchar>( y, x) > 0 ){
                    img.at<cv::Vec3b>(y,x)[z]  = img.at<cv::Vec3b>(y,x)[z];
                }
                else{
                    img.at<cv::Vec3b>(y,x)[z]  = 0;
                }
                
            }
        }
    }
    
    
    return img;
}
///**************************************



///**************************************
- (NSArray*) getColors{
    
    return [self getColors:10 useSaliency:false];
}
///**************************************


///**************************************
- (NSArray*) getColors:(int)numberOfColors useSaliency:(bool)saliency{
    
    NSMutableArray *colorArray = [[NSMutableArray alloc]initWithCapacity:numberOfColors];
    
    cv::Mat src;
    cv::cvtColor(processingImage, src, cv::COLOR_BGRA2BGR);
    
    cv::resize(src, src, cv::Size(480, 640));
    
    double size = 300;
    cv::Rect myROI((src.cols - size) / 2,
                   (src.rows - size) / 2,
                   size,
                   size);
    cv::Mat croppedImage = src(myROI);
    
    cv::Mat samples(croppedImage.rows * croppedImage.cols, 3, CV_32F);
    for( int y = 0; y < croppedImage.rows; y++ ) {
        for( int x = 0; x < croppedImage.cols; x++ ){
            for( int z = 0; z < 3; z++){
                samples.at<float>(y + x*croppedImage.rows, z) = croppedImage.at<cv::Vec3b>(y,x)[z];
            }
        }
    }
    
    int clusterCount = numberOfColors;
    cv::Mat labels;
    int attempts = 10;
    cv::Mat centers;
    
    cv::kmeans(samples,
               clusterCount,
               labels,
               cv::TermCriteria(cv::TermCriteria::MAX_ITER + cv::TermCriteria::EPS,
                                50,
                                0.0001),
               attempts, cv::KMEANS_PP_CENTERS, centers );
    
    for (int i = 0; i < clusterCount; i ++){
        [colorArray addObject:[UIColor colorWithRed:CGFloat(centers.at<float>(i, 0)) / 255
                                              green:CGFloat(centers.at<float>(i, 1)) / 255
                                               blue:CGFloat(centers.at<float>(i, 2)) / 255
                                              alpha:1]];
    }
    
    return colorArray;
    
}
///**************************************





///**************************************
- (void)startVideo
{
    videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    if (![videoCamera running]){
        [videoCamera start];}
    [self getBackground];
}
///**************************************

///**************************************
- (void)stopVideo
{
    if ([videoCamera running]){
        [videoCamera stop];}
}
///**************************************

///**************************************
- (void) switchVideoCamera{
    [videoCamera stop];
    UIImageView *parentView = (UIImageView *)videoCamera.parentView;
    AVCaptureDevicePosition position = videoCamera.defaultAVCaptureDevicePosition;
    
    
    [self createOpenCVVideoCameraWithImageView:parentView];
    if (position == AVCaptureDevicePositionFront ){
        videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack; // Use the back camera
    }
    else{
        videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront; // Use the front camera
    }
    
    [videoCamera start];
}
///**************************************



///**************************************
- (void) startPhoto
{
    if (![photoCamera running]){
        [photoCamera start];}
}
///**************************************


///**************************************
- (void) stopPhoto
{
    if ([photoCamera running]){
        [photoCamera stop];}
}
///**************************************



///**************************************
- (void) switchPhotoCamera{
    [photoCamera stop];
    UIImageView *parentView = (UIImageView *)photoCamera.parentView;
    AVCaptureDevicePosition position = photoCamera.defaultAVCaptureDevicePosition;
    
    [self createOpenCVPhotoCameraWithImageView:parentView];
    if (position == AVCaptureDevicePositionFront ){
        photoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack; // Use the back camera
    }
    else{
        photoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront; // Use the back camera
    }
    
    [photoCamera start];
}
///**************************************



///**************************************
- (void) startCalibration{
    
    calibrator->startCapturing();
}
///**************************************




///**************************************
Calibrator::Calibrator(std::string outputPath, OpenCVWrapper *wrapperSender) : squareSize(0.25f), aspectRatio(1.f), pattern(ASYMMETRIC_CIRCLES_GRID), mode(DETECTION), writeExtrinsics(false), writePoints(false), flipVertical(false), undistortImage(false), nframes(40), flags(0), delay(1000), prevTimestamp(0) {
    boardSize = cv::Size(4, 11);
    
    wrapper = wrapperSender;
    
    this->outputPath = outputPath;
}

void Calibrator::startCapturing() {
    mode = CAPTURING;
    imagePoints.clear();
    
    [wrapper.delegate calibrationStarted];
}

int Calibrator::processFrame(cv::Mat frame) {
    
    cv::Mat viewGray;
    
    imageSize = frame.size();
    
    vector<Point2f> pointbuf;
    cvtColor(frame, viewGray, COLOR_BGR2GRAY);
    
    bool found;
    switch( pattern )
    {
        case CHESSBOARD: {
            int cornerFlag = cv::CALIB_CB_ADAPTIVE_THRESH | cv::CALIB_CB_NORMALIZE_IMAGE | cv::CALIB_CB_FILTER_QUADS;
//            int cornerFlag = 0;
            found = findChessboardCorners( frame, boardSize, pointbuf, cornerFlag);
            break;
        }
        case CIRCLES_GRID:
            found = findCirclesGrid( frame, boardSize, pointbuf );
            break;
        case ASYMMETRIC_CIRCLES_GRID:
            found = findCirclesGrid( viewGray, boardSize, pointbuf, CALIB_CB_ASYMMETRIC_GRID );
            break;
        default:
            return fprintf( stderr, "Unknown pattern type\n" ), -1;
    }
    
    // improve the found corners' coordinate accuracy
    if( pattern == CHESSBOARD && found) cornerSubPix( viewGray, pointbuf, cv::Size(20,20),
                                                     cv::Size(-1,-1), TermCriteria( cv::TermCriteria::EPS + cv::TermCriteria::MAX_ITER, 30, 0.1 ));
    
    if( mode == CAPTURING && found &&
       (clock() - prevTimestamp > delay*1e-3*CLOCKS_PER_SEC) )
    {
        printf("pattern found\n");
        imagePoints.push_back(pointbuf);
        prevTimestamp = clock();
        
        [wrapper.delegate patternFound];
    }
    
    if(found) {
        drawChessboardCorners( frame, boardSize, Mat(pointbuf), found );
    } else {
        [wrapper.delegate patternNotFound];
        printf("not found\n");
    }
    
    string msg = mode == CAPTURING ? "100/100" :
    mode == CALIBRATED ? "Calibrated" : "Press 'g' to start";
    int baseLine = 0;
    cv::Size textSize = getTextSize(msg, 1, 1, 1, &baseLine);
    cv::Point textOrigin(frame.cols - 2*textSize.width - 10, frame.rows - 2*baseLine - 10);
    
    if( mode == CAPTURING )
    {
        if(undistortImage)
            msg = format( "%d/%d Undist", (int)imagePoints.size(), nframes );
        else
            msg = format( "%d/%d", (int)imagePoints.size(), nframes );
    }
    
    putText( frame, msg, textOrigin, 1, 1,
            mode != CALIBRATED ? Scalar(0,0,255) : Scalar(0,255,0));
    
    if( mode == CALIBRATED && undistortImage )
    {
        Mat temp = frame.clone();
        undistort(temp, frame, cameraMatrix, distCoeffs);
    }
    
    if( mode == CAPTURING && imagePoints.size() >= (unsigned)nframes )
    {
        if( runAndSave(imagePoints, imageSize,
                       boardSize, pattern, squareSize, aspectRatio,
                       flags, cameraMatrix, distCoeffs,
                       writeExtrinsics, writePoints))
        {
            printf("calibration done\n");
            mode = CALIBRATED;
        }
        else
        {
            printf("calibration done error\n");
            mode = DETECTION;
        }
    }
    return 0;
}

static double computeReprojectionErrors(
                                        const vector<vector<Point3f> >& objectPoints,
                                        const vector<vector<Point2f> >& imagePoints,
                                        const vector<Mat>& rvecs, const vector<Mat>& tvecs,
                                        const Mat& cameraMatrix, const Mat& distCoeffs,
                                        vector<float>& perViewErrors )
{
    vector<Point2f> imagePoints2;
    int i, totalPoints = 0;
    double totalErr = 0, err;
    perViewErrors.resize(objectPoints.size());
    
    for( i = 0; i < (int)objectPoints.size(); i++ )
    {
        projectPoints(Mat(objectPoints[i]), rvecs[i], tvecs[i],
                      cameraMatrix, distCoeffs, imagePoints2);
        err = norm(Mat(imagePoints[i]), Mat(imagePoints2), CV_L2);
        int n = (int)objectPoints[i].size();
        perViewErrors[i] = (float)std::sqrt(err*err/n);
        totalErr += err*err;
        totalPoints += n;
    }
    
    return std::sqrt(totalErr/totalPoints);
}

void Calibrator::calcChessboardCorners(cv::Size boardSize, float squareSize, vector<Point3f>& corners, Pattern patternType)
{
    corners.resize(0);
    
    switch(patternType)
    {
        case CHESSBOARD:
        case CIRCLES_GRID:
            for( int i = 0; i < boardSize.height; i++ )
                for( int j = 0; j < boardSize.width; j++ )
                    corners.push_back(Point3f(float(j*squareSize),
                                              float(i*squareSize), 0));
            break;
            
        case ASYMMETRIC_CIRCLES_GRID:
            for( int i = 0; i < boardSize.height; i++ )
                for( int j = 0; j < boardSize.width; j++ )
                    corners.push_back(Point3f(float((2*j + i % 2)*squareSize),
                                              float(i*squareSize), 0));
            break;
            
        default:
            CV_Error(CV_StsBadArg, "Unknown pattern type\n");
    }
}

bool Calibrator::runCalibration( vector<vector<Point2f> > imagePoints,
                                cv::Size imageSize, cv::Size boardSize, Pattern patternType,
                           float squareSize, float aspectRatio,
                           int flags, Mat& cameraMatrix, Mat& distCoeffs,
                           vector<Mat>& rvecs, vector<Mat>& tvecs,
                           vector<float>& reprojErrs,
                           double& totalAvgErr)
{
    cameraMatrix = Mat::eye(3, 3, CV_64F);
    if( flags & cv::CALIB_FIX_ASPECT_RATIO )
        cameraMatrix.at<double>(0,0) = aspectRatio;
    
    distCoeffs = Mat::zeros(8, 1, CV_64F);
    
    vector<vector<Point3f> > objectPoints(1);
    calcChessboardCorners(boardSize, squareSize, objectPoints[0], patternType);
    
    objectPoints.resize(imagePoints.size(),objectPoints[0]);
    
    double rms = calibrateCamera(objectPoints, imagePoints, imageSize, cameraMatrix,
                                 distCoeffs, rvecs, tvecs, flags| cv::CALIB_FIX_K4 | cv::CALIB_FIX_K5);
    ///*|CV_CALIB_FIX_K3*/|CV_CALIB_FIX_K4|CV_CALIB_FIX_K5);
    printf("RMS error reported by calibrateCamera: %g\n", rms);
    
    bool ok = checkRange(cameraMatrix) && checkRange(distCoeffs);
    
    totalAvgErr = computeReprojectionErrors(objectPoints, imagePoints,
                                            rvecs, tvecs, cameraMatrix, distCoeffs, reprojErrs);
    
    return ok;
}


void Calibrator::saveCameraParams(cv::Size imageSize, cv::Size boardSize,
                                  float squareSize, float aspectRatio, int flags,
                                  const Mat& cameraMatrix, const Mat& distCoeffs,
                                  const vector<Mat>& rvecs, const vector<Mat>& tvecs,
                                  const vector<float>& reprojErrs,
                                  const vector<vector<Point2f> >& imagePoints,
                                  double totalAvgErr )
{
    FileStorage fs( this->outputPath, FileStorage::WRITE );
    
    time_t tt;
    time( &tt );
    struct tm *t2 = localtime( &tt );
    char buf[1024];
    strftime( buf, sizeof(buf)-1, "%c", t2 );
    
    fs << "calibration_time" << buf;
    
    if( !rvecs.empty() || !reprojErrs.empty() )
        fs << "nframes" << (int)std::max(rvecs.size(), reprojErrs.size());
    fs << "image_width" << imageSize.width;
    fs << "image_height" << imageSize.height;
    fs << "board_width" << boardSize.width;
    fs << "board_height" << boardSize.height;
    fs << "square_size" << squareSize;
    
    if( flags & cv::CALIB_FIX_ASPECT_RATIO )
        fs << "aspectRatio" << aspectRatio;
    
    if( flags != 0 )
    {
        sprintf( buf, "flags: %s%s%s%s",
                flags & cv::CALIB_USE_INTRINSIC_GUESS ? "+use_intrinsic_guess" : "",
                flags & cv::CALIB_FIX_ASPECT_RATIO ? "+fix_aspectRatio" : "",
                flags & cv::CALIB_FIX_PRINCIPAL_POINT ? "+fix_principal_point" : "",
                flags & cv::CALIB_ZERO_TANGENT_DIST ? "+zero_tangent_dist" : "" );
        fs << buf;
    //    cvWriteComment( *fs, buf, 0 );
    }
    
    fs << "flags" << flags;
    
    fs << "camera_matrix" << cameraMatrix;
    fs << "distortion_coefficients" << distCoeffs;
    
    fs << "avg_reprojection_error" << totalAvgErr;
    if( !reprojErrs.empty() )
        fs << "per_view_reprojection_errors" << Mat(reprojErrs);
    
    if( !rvecs.empty() && !tvecs.empty() )
    {
        CV_Assert(rvecs[0].type() == tvecs[0].type());
        Mat bigmat((int)rvecs.size(), 6, rvecs[0].type());
        for( int i = 0; i < (int)rvecs.size(); i++ )
        {
            Mat r = bigmat(Range(i, i+1), Range(0,3));
            Mat t = bigmat(Range(i, i+1), Range(3,6));
            
            CV_Assert(rvecs[i].rows == 3 && rvecs[i].cols == 1);
            CV_Assert(tvecs[i].rows == 3 && tvecs[i].cols == 1);
            //*.t() is MatExpr (not Mat) so we can use assignment operator
            r = rvecs[i].t();
            t = tvecs[i].t();
        }
   //     cvWriteComment( *fs, "a set of 6-tuples (rotation vector + translation vector) for each view", 0 );
        fs << "extrinsic_parameters" << bigmat;
    }
    
    if( !imagePoints.empty() )
    {
        Mat imagePtMat((int)imagePoints.size(), (int)imagePoints[0].size(), CV_32FC2);
        for( int i = 0; i < (int)imagePoints.size(); i++ )
        {
            Mat r = imagePtMat.row(i).reshape(2, imagePtMat.cols);
            Mat imgpti(imagePoints[i]);
            imgpti.copyTo(r);
        }
        fs << "image_points" << imagePtMat;
    }
    
    
    std::vector<double> cameraMatrixVector;
    if (cameraMatrix.isContinuous()) {
      cameraMatrixVector.assign((double*)cameraMatrix.datastart, (double*)cameraMatrix.dataend);
    } else {
      for (int i = 0; i < cameraMatrix.rows; ++i) {
        cameraMatrixVector.insert(cameraMatrixVector.end(), cameraMatrix.ptr<double>(i), cameraMatrix.ptr<double>(i)+cameraMatrix.cols);
      }
    }
    
    NSMutableArray *camMatrixArray = [NSMutableArray arrayWithCapacity:cameraMatrixVector.size()];
    for (int i = 0; i < cameraMatrixVector.size(); i ++){
        double d = cameraMatrixVector[i];
        [camMatrixArray addObject:[NSNumber numberWithDouble:d]];
        //[camMatrixArray addObject:array[i]];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:camMatrixArray forKey:@"camMatrix"];
    
    
    std::vector<double> distCoeffVector;
    if (distCoeffs.isContinuous()) {
      distCoeffVector.assign((double*)distCoeffs.datastart, (double*)distCoeffs.dataend);
    } else {
      for (int i = 0; i < distCoeffs.rows; ++i) {
        distCoeffVector.insert(distCoeffVector.end(), distCoeffs.ptr<double>(i), distCoeffs.ptr<double>(i)+distCoeffs.cols);
      }
    }
    
    
    NSMutableArray *distCoeffsArray = [NSMutableArray arrayWithCapacity:distCoeffVector.size()];
    for (int i = 0; i < distCoeffVector.size(); i ++){
        double d = distCoeffVector[i];
        [distCoeffsArray addObject:[NSNumber numberWithDouble:d]];
        //[camMatrixArray addObject:array[i]];
    }
    
    
    [[NSUserDefaults standardUserDefaults] setObject:distCoeffsArray forKey:@"distCoeffs"];
    
    printf("saved camera parameter to %s.", this->outputPath.c_str());
    
    [wrapper.delegate calibrationFinished];
    
}

bool Calibrator::runAndSave(const vector<vector<Point2f> >& imagePoints,
                            cv::Size imageSize, cv::Size boardSize, Pattern patternType, float squareSize,
                            float aspectRatio, int flags, Mat& cameraMatrix,
                            Mat& distCoeffs, bool writeExtrinsics, bool writePoints )
{
    vector<Mat> rvecs, tvecs;
    vector<float> reprojErrs;
    double totalAvgErr = 0;
    
    bool ok = runCalibration(imagePoints, imageSize, boardSize, patternType, squareSize,
                             aspectRatio, flags, cameraMatrix, distCoeffs,
                             rvecs, tvecs, reprojErrs, totalAvgErr);
    printf("%s. avg reprojection error = %.2f\n",
           ok ? "Calibration succeeded" : "Calibration failed",
           totalAvgErr);
    
    if( ok )
        saveCameraParams(imageSize,
                         boardSize, squareSize, aspectRatio,
                         flags, cameraMatrix, distCoeffs,
                         writeExtrinsics ? rvecs : vector<Mat>(),
                         writeExtrinsics ? tvecs : vector<Mat>(),
                         writeExtrinsics ? reprojErrs : vector<float>(),
                         writePoints ? imagePoints : vector<vector<Point2f> >(),
                         totalAvgErr );
    return ok;
}
///**************************************


@end
