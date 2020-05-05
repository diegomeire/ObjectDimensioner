//
//  OpenCVWrapper.h
//  ObjectDimensioner
//
//  Created by Diego Meire on 31/07/19.
//  Copyright © 2019 Diege Miere. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>



@protocol OpenCVWrapperDelegate

- (void) widthChanged:(float)width;
- (void) heightChanged:(float)height;
- (void) pictureTakenWithColors:(NSArray *)colors;
- (void) calibrationFinished;
- (void) calibrationStarted;
- (void) patternFound;
- (void) patternNotFound;


@end


@interface OpenCVWrapper : NSObject {
}

- (instancetype)init;
- (void) createOpenCVVideoCameraWithImageView:(UIImageView *)imageView;
- (void) startVideo;
- (void) stopVideo;
- (void) switchVideoCamera;
    
- (void) createOpenCVPhotoCameraWithImageView:(UIImageView *)imageView;
- (void) startPhoto;
- (void) stopPhoto;
- (void) takePicture;
- (void) switchPhotoCamera;

- (void) saveObjectRealWidth:(double)objectWidth andHeight:(double)objectHeight;

- (void) getBackground;
+ (instancetype)shared;

- (NSArray*) getColors;
- (NSArray*) getColors:(int)numberOfColors useSaliency:(bool)saliency;
- (NSArray*) getColorsForImage:(UIImage *)image;

- (void) clearColorsToFind;
- (void) addColorToFind:(UIColor *)color;
- (void) startCalibration;

@property (nonatomic, assign) CGFloat hue;
@property (nonatomic, assign) CGFloat saturation;

@property (nonatomic, assign) CGFloat minBrightness;
@property (nonatomic, assign) CGFloat maxBrightness;

@property (nonatomic, assign) CGFloat minSaturation;
@property (nonatomic, assign) CGFloat maxSaturation;

@property (nonatomic, assign) CGFloat value;
@property (nonatomic, assign) bool fullColorRange;

@property (nonatomic, assign) int numberOfMeanColors;

@property (nonatomic, assign) int threshold;
@property (nonatomic, assign) int maxThreshold;

@property (nonatomic, assign) double objectWidth;
@property (nonatomic, assign) double objectHeight;


@property (nonatomic, assign) double pixelsPerMetricHorizontal;
@property (nonatomic, assign) double pixelsPerMetricVertical;

@property (nonatomic, assign) double widthInPixels;
@property (nonatomic, assign) double heightInPixels;

@property (nonatomic, assign) double width;
@property (nonatomic, assign) double height;

@property (nonatomic, weak) id <OpenCVWrapperDelegate> delegate;
@property (nonatomic, assign) bool calibrating;
    



@end

