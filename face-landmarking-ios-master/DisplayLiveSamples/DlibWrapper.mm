//
//  DlibWrapper.m
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import "DlibWrapper.h"

#include <dlib/clustering.h>
#include <dlib/string.h>


#include <dlib/image_processing.h>
#include <dlib/image_io.h>
#include <dlib/dnn.h>


using namespace dlib;
using namespace std;
template <template <int,template<typename>class,int,typename> class block, int N, template<typename>class BN, typename SUBNET>
using residual = add_prev1<block<N,BN,1,tag1<SUBNET>>>;

template <template <int,template<typename>class,int,typename> class block, int N, template<typename>class BN, typename SUBNET>
using residual_down = add_prev2<avg_pool<2,2,2,2,skip1<tag2<block<N,BN,2,tag1<SUBNET>>>>>>;

template <int N, template <typename> class BN, int stride, typename SUBNET>
using block  = BN<con<N,3,3,1,1,relu<BN<con<N,3,3,stride,stride,SUBNET>>>>>;

template <int N, typename SUBNET> using ares      = relu<residual<block,N,affine,SUBNET>>;
template <int N, typename SUBNET> using ares_down = relu<residual_down<block,N,affine,SUBNET>>;

template <typename SUBNET> using alevel0 = ares_down<256,SUBNET>;
template <typename SUBNET> using alevel1 = ares<256,ares<256,ares_down<256,SUBNET>>>;
template <typename SUBNET> using alevel2 = ares<128,ares<128,ares_down<128,SUBNET>>>;
template <typename SUBNET> using alevel3 = ares<64,ares<64,ares<64,ares_down<64,SUBNET>>>>;
template <typename SUBNET> using alevel4 = ares<32,ares<32,ares<32,SUBNET>>>;

using anet_type = loss_metric<fc_no_bias<128,avg_pool_everything<
alevel0<
alevel1<
alevel2<
alevel3<
alevel4<
max_pool<3,3,2,2,relu<affine<con<32,7,7,2,2,
input_rgb_image_sized<150>
>>>>>>>>>>>>;
@interface DlibWrapper ()

@property (assign) BOOL prepared;

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects;

@end
@implementation DlibWrapper {
    dlib::shape_predictor sp;
    std::vector<matrix<float,0,1>> face_descriptors;
    matrix<float,0,1> input_descriptor;
    UIImage *input_image;
    NSInteger recCount;
    NSMutableArray *fidArray;
    
    
    
    
}
anet_type net;

// ----------------------------------------------------------------------------------------

std::vector<matrix<rgb_pixel>> jitter_image(
                                            const matrix<rgb_pixel>& img
                                            );

// ----------------------------------------------------------------------------------------

- (instancetype)init {
    self = [super init];
    if (self) {
        _prepared = NO;
    }
    recCount = 0;
    fidArray = [[NSMutableArray alloc] init];
    return self;
}

- (void)prepare {
    NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_5_face_landmarks" ofType:@"dat"];
    std::string modelFileNameCString = [modelFileName UTF8String];
    
    dlib::deserialize(modelFileNameCString) >> sp;
    
    // FIXME: test this stuff for memory leaks (cpp object destruction)
    
    NSString *dnnFileName = [[NSBundle mainBundle] pathForResource:@"dlib_face_recognition_resnet_model_v1" ofType:@"dat"];
     std::string dnnFileNameCString = [dnnFileName UTF8String];
    dlib::deserialize(dnnFileNameCString) >> net;
    self.prepared = YES;
}





-(void)recognizeAt:(NSInteger)recIndex{
    self.imageRecognizeCheck = !self.imageRecognizeCheck;
    if (self.imageRecognizeCheck){
        input_descriptor = face_descriptors[recIndex];
        input_image = ((FaceID*)fidArray[recIndex]).faceImage;
    } else {
        [self.faceDelegate onRecognised:nil];
    }
}

- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {
    
    if (!self.prepared) {
        [self prepare];
    }
    
    dlib::array2d<dlib::bgr_pixel> img;
    matrix<rgb_pixel> img2;
    // MARK: magic
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    // set_size expects rows, cols format
    img.set_size(height, width);
    img2.set_size(height, width);
    // copy samplebuffer image data into dlib image format
    img.reset();
    long position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();
        dlib::rgb_pixel& rgbpx = img2(position);
        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        char b = baseBuffer[bufferLocation];
        char g = baseBuffer[bufferLocation + 1];
        char r = baseBuffer[bufferLocation + 2];
        
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];
        
        dlib::bgr_pixel newpixel(b, g, r);
        dlib::rgb_pixel rgbPixel(r,g,b);
        rgbpx = rgbPixel;
        pixel = newpixel;
        
        position++;
    }
    
    // unlock buffer again until we need it again
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    // convert the face bounds list to dlib format
    std::vector<dlib::rectangle> convertedRectangles = [DlibWrapper convertCGRectValueArray:rects];
    
    // for every detected face
    
    recCount++;
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
    {
        dlib::rectangle oneFaceRect = convertedRectangles[j];
        
        // detect all landmarks
        dlib::full_object_detection shape = sp(img, oneFaceRect);
        for (unsigned long k = 0; k < shape.num_parts(); k++) {
            dlib::point p = shape.part(k);
            draw_solid_circle(img, p, 5, dlib::rgb_pixel(0, 255, 255));
        }
        
        if (recCount > 5 ){
            recCount = 0;
        }  else {
            continue;
        }
        if (recCount == 0){
            std::vector<matrix<rgb_pixel>> faces;
            
            matrix<rgb_pixel> face_chip;
            extract_image_chip(img2, get_face_chip_details(shape,150,0.25), face_chip);
            faces.push_back(move(face_chip));
            // and draw them into the image (samplebuffer)
            
            
            std::vector<matrix<float,0,1>> desc = net(faces);
            
            if (self.imageRecognizeCheck){
                if (fidArray.count != 0){
                    UIImage *image;
                    if (length(input_descriptor - desc[0]) < 0.5){
                        image = input_image;
                    }
                    [self.faceDelegate onRecognised:image];
                }
            } else {
                BOOL found = NO;
                for (int index = 0; index < face_descriptors.size(); index++ ){
                    matrix<float,0,1> face_id = face_descriptors[index];
                    if ( length(face_id - desc[0]) < 0.4){
                        NSLog(@"face recognised previously");
                        found = YES;
                        break;
                    }
                }
                if (!found){
                    face_descriptors.push_back(desc[0]);
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    const int pixels_w = (int)(oneFaceRect.right() - oneFaceRect.left());
                    const int pixels_h = (int)(oneFaceRect.bottom() - oneFaceRect.top());
                    const int bytesPerRow = 4 * pixels_w;
                    CGContextRef bmContext = CGBitmapContextCreate(NULL, pixels_w,
                                                                   pixels_h, 8,bytesPerRow,
                                                                   colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
                    
                    long position = 0;
                    char * data = (char *)CGBitmapContextGetData(bmContext);
                    
                    
                    
                    for (int i = (int)oneFaceRect.top(); i < oneFaceRect.bottom(); i++){
                        if (i < 0 || i >= height){
                            continue ;
                        }
                        for(int j = (int)oneFaceRect.left(); j < oneFaceRect.right(); j++){
                            if (j < 0 || j >= width){
                                continue ;
                            }
                            dlib::bgr_pixel pixel = img[i][j];
                            long bufferLocation =  position * 4;//j * 512  + i; //(row * width + column) * 4;
                            data[bufferLocation] =  pixel.blue;
                            data[bufferLocation + 1] = pixel.green;
                            data[bufferLocation + 2] = pixel.red;
                            data[bufferLocation + 3] = 255;
                            position++;
                        }
                    }
                    CGImageRef newImage = CGBitmapContextCreateImage(bmContext);
                    
                    UIImage *image = [[UIImage alloc] initWithCGImage:newImage];
                    CGImageRelease(newImage);
                    CGContextRelease(bmContext);
                    
                    CGColorSpaceRelease(colorSpace);
                    
                    FaceID *fid = [[FaceID alloc] init:j withImage:image];
                    [fidArray addObject:fid];
                    //                [self.faceDelegate didFoundFaces:fidArray];
                    [self.faceDelegate onFaceFound:fid];
                }
            }
        }
    }
//    std::vector<matrix<float,0,1>> desc = net(faces);
//    if (self.imageRecognize){
//        self.imageRecognize = false;
//        face_descriptors = desc;
//    }
//
//    if (self.imageRecognizeCheck){
//        const float value = length(face_descriptors[0]-desc[0]);
//        if ( value < 0.5)
//        {
//            NSLog(@"recognized face found %f",value);
//        }
//    }
    
    
    
//    for (int i = 0; i < face_descriptors.size(); i++){
//        const matrix<float,0,1> data = face_descriptors[i];
//        NSLog(@"column____ %ld_____row ____%ld",data.nc(),data.nr());
//        for (int j = 0; j < data.size(); j++ ){
//            NSLog(@"data is %f", data(0,j));
//        }
//    }
    // lets put everything back where it belongs
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    // copy dlib image data back into samplebuffer
    img.reset();
    position = 0;
    while (img.move_next()) {
        dlib::bgr_pixel& pixel = img.element();
        
        // assuming bgra format here
        long bufferLocation = position * 4; //(row * width + column) * 4;
        baseBuffer[bufferLocation] = pixel.blue;
        baseBuffer[bufferLocation + 1] = pixel.green;
        baseBuffer[bufferLocation + 2] = pixel.red;
        //        we do not need this
        //        char a = baseBuffer[bufferLocation + 3];
        
        position++;
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects {
    std::vector<dlib::rectangle> myConvertedRects;
    for (NSValue *rectValue in rects) {
        CGRect rect = [rectValue CGRectValue];
        long left = rect.origin.x;
        long top = rect.origin.y;
        long right = left + rect.size.width;
        long bottom = top + rect.size.height;
        dlib::rectangle dlibRect(left, top, right, bottom);

        myConvertedRects.push_back(dlibRect);
    }
    return myConvertedRects;
}

//float __len(float l1, float l2){
//
//}

@end

@interface FaceID(){
    
}



@end
@implementation FaceID
-(instancetype)init:(NSInteger)fid withImage:(UIImage *)_img{
    self = [super init];
    self.face_id = fid;
    self.faceImage = _img;
    return self;
}



@end
