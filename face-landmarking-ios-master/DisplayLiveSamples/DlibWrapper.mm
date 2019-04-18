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
#include <dlib/matrix.h>

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
    float vector[128];
    
    BOOL shouldSkip;
    
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
    input_descriptor.set_size(128, 1);
    self.singleRecognizer = YES;
    return self;
}

- (void)prepare {
    NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
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
    
//    recCount++;
    int indices[15] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
    int idx = 0;
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
    {
        dlib::rectangle oneFaceRect = convertedRectangles[j];
        
        // detect all landmarks
        dlib::full_object_detection shape = sp(img, oneFaceRect);
        if (recCount == 0){
            std::vector<matrix<rgb_pixel>> faces;
            matrix<rgb_pixel> face_chip;
            extract_image_chip(img2, get_face_chip_details(shape,150,0.25), face_chip);
            faces.push_back(move(face_chip));
            std::vector<matrix<float,0,1>> desc = net(faces);
            if (self.imageRecognizeCheck){
                
                if (!self.singleRecognizer){
                    for(int i = 0; i < face_descriptors.size(); i++){
                        if(length(face_descriptors[i] - desc[0]) < 0.5){
                            indices[idx++] = i;
                            break;
                        }
                    }
                } else {
                    float value = 0;
                    value = length(input_descriptor - desc[0]);
                    if (value < 0.5){
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
                                data[bufferLocation] = pixel.red;
                                data[bufferLocation + 1] = pixel.green;
                                data[bufferLocation + 2] = pixel.blue;
                                data[bufferLocation + 3] = 255;
                                position++;
                            }
                        }
                        CGImageRef newImage = CGBitmapContextCreateImage(bmContext);
                        
                        UIImage *image = [[UIImage alloc] initWithCGImage:newImage];
                        CGImageRelease(newImage);
                        CGContextRelease(bmContext);
                        CGColorSpaceRelease(colorSpace);
                        [self.faceDelegate onRecognised:image];
                        break;
                    } else {
                        [self.faceDelegate onRecognised:nil];
                    }
                }
                if (!self.singleRecognizer){
                    [self.faceDelegate onFindIndices:indices count:idx];
                }
            }
        }
    }
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

-(void)setFaceVectors:(float *)vectors {
    matrix<float,0,1> desc;
    desc.set_size(128, 1);
    for(int j = 0; j < 128; j++){
        desc(j,0) = vectors[j];
    }
    face_descriptors.push_back(desc);
}

-(void)recognizeVector:(float *)vectors {
//    input_descriptor.set_size(0, 128);
    self.imageRecognizeCheck = NO;
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        usleep(300);
        for(int i = 0; i < 128; i++){
            //        vector[i] = vectors[i];
            input_descriptor(i,0) = vectors[i];
        }
        self.imageRecognizeCheck = YES;
//    });
    
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
