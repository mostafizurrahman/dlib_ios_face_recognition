//
//  DlibWrapper.h
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>




@interface FaceID:NSObject
@property (readwrite) NSInteger face_id;
@property (readwrite) UIImage *faceImage;
-(instancetype)init:(NSInteger)fid withImage:(UIImage *)_img;

@end
@protocol RecognitionDelegate<NSObject>
-(void)didFoundFaces:(NSMutableArray *)fidArray;
-(void)onFaceFound:(FaceID *)faceID;
-(void)onRecognised:(nullable UIImage *)image;
@end
@interface DlibWrapper : NSObject

- (instancetype)init;
- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects;
- (void)prepare;
@property (readwrite) BOOL imageRecognize;
@property (readwrite) BOOL imageRecognizeCheck;
@property (readwrite, weak) id<RecognitionDelegate> faceDelegate;
-(void)performRecognition;
-(void)recognizeAt:(NSInteger)recIndex;
@end
