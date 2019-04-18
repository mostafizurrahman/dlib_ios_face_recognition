//
//  DlibWrapper.h
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>//




@interface FaceID:NSObject
@property (readwrite) NSInteger face_id;
@property (readwrite) UIImage * _Nullable faceImage;
-(instancetype)init:(NSInteger)fid withImage:(UIImage *)_img;

@end
@protocol RecognitionDelegate<NSObject>
-(void)didFoundFaces:(NSMutableArray *)fidArray;
-(void)onFaceFound:(FaceID *)faceID;
-(void)onRecognised:(nullable UIImage *)image;
@end
@interface DlibWrapper : NSObject

- (instancetype _Nullable )init;
- (void)doWorkOnSampleBuffer:(CMSampleBufferRef _Nullable )sampleBuffer inRects:(NSArray<NSValue *> *_Nullable)rects;
- (void)prepare;
@property (readwrite) BOOL imageRecognize;
@property (readwrite) BOOL imageRecognizeCheck;
@property (readwrite, weak) id<RecognitionDelegate> _Nullable faceDelegate;
-(void)performRecognition;
-(void)recognizeAt:(NSInteger)recIndex;
-(void)recognizeVector:(float *)vectors;


@end
