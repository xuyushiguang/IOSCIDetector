//
//  ViewController.m
//  VideoToolBoxEncodeH264
//
//  Created by AnDong on 2018/6/25.
//  Copyright © 2018年 AnDong. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "FaceRecognitionManager.h"
static NSString *const H264FilePath = @"test.h264";

@interface ViewController ()<AVCaptureMetadataOutputObjectsDelegate>
{
    
    //录制队列
    dispatch_queue_t captureQueue;
    
    //编码队列
    dispatch_queue_t encodeQueue;
    
    //编码session
    VTCompressionSessionRef encodingSession;
    
    
    UIView * resultView;
    
}

@property (nonatomic,strong)AVCaptureSession *captureSession; //输入和输出数据传输session
@property (nonatomic,strong)AVCaptureDeviceInput *captureDeviceInput; //从AVdevice获得输入数据
@property (nonatomic,strong)AVCaptureMetadataOutput *metadataOutput; //获取输出数据
@property (nonatomic,strong)AVCaptureVideoPreviewLayer *previewLayer; //预览layer

@property (nonatomic,strong)UIButton *startBtn;
@property (nonatomic,strong)UILabel *titleLabel;

@property ()int abc;




@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //初始化UI和参数
    [self initUIAndParameter];
    
}


- (void)initUIAndParameter{
    
    [self.view addSubview:self.startBtn];
    [self.view addSubview:self.titleLabel];
    
    //初始化队列
    captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

#pragma mark - EventHanle

- (void)startBtnAction{
    BOOL isRunning = self.captureSession && self.captureSession.running;
    
    if (isRunning) {
        //停止采集编码
        [self.startBtn setTitle:@"Start" forState:UIControlStateNormal];
        [self endCaputureSession];
    }
    else{
        //开始采集编码
        [self.startBtn setTitle:@"End" forState:UIControlStateNormal];
        [self startCaputureSession];
    }
}


- (void)startCaputureSession{
    
    [self initCapture];
    [self initPreviewLayer];
    
    //开始采集
    [self.captureSession startRunning];
}

- (void)endCaputureSession{
    //停止采集
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
}

#pragma mark - 摄像头采集端

//初始化摄像头采集端
- (void)initCapture{
    
    self.captureSession = [[AVCaptureSession alloc]init];

    //设置录制720p
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    AVCaptureDevice *inputCamera = [self cameraWithPostion:AVCaptureDevicePositionBack];
    
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
    
    if ([self.captureSession canAddInput:self.captureDeviceInput]) {
        [self.captureSession addInput:self.captureDeviceInput];
    }
    
    self.metadataOutput  = [[AVCaptureMetadataOutput alloc] init];
    if ([self.captureSession canAddOutput:self.metadataOutput]) {
        [self.captureSession addOutput:self.metadataOutput];
    }
    
    [self.metadataOutput setMetadataObjectsDelegate:self queue:captureQueue];
    self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
    self.metadataOutput.rectOfInterest = self.view.bounds;
    
    
    
    //建立连接
    AVCaptureConnection *connection = [self.metadataOutput connectionWithMediaType:AVMediaTypeMetadata];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
}

//config 摄像头预览layer
- (void)initPreviewLayer{
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [self.previewLayer setFrame:self.view.bounds];
    [self.view.layer addSublayer:self.previewLayer];
}


//兼容iOS10以上获取AVCaptureDevice
- (AVCaptureDevice *)cameraWithPostion:(AVCaptureDevicePosition)position{
    NSString *version = [UIDevice currentDevice].systemVersion;
    if (version.doubleValue >= 10.0) {
        // iOS10以上
        AVCaptureDeviceDiscoverySession *devicesIOS10 = [AVCaptureDeviceDiscoverySession  discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
        NSArray *devicesIOS  = devicesIOS10.devices;
        for (AVCaptureDevice *device in devicesIOS) {
            if ([device position] == position) {
                return device;
            }
        }
        return nil;
    } else {
        // iOS10以下
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices)
        {
            if ([device position] == position)
            {
                return device;
            }
        }
        return nil;
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    dispatch_async(dispatch_get_main_queue(), ^{

        if (self->resultView) {
            [self->resultView removeFromSuperview];
        }
        self->resultView = [[UIView alloc] initWithFrame:self.previewLayer.bounds];
        [self.view addSubview:self->resultView];

        for (AVMetadataFaceObject *face in metadataObjects) {
            //将摄像头捕捉的人脸位置转换到屏幕位置
            AVMetadataObject *tranformFace = [self.previewLayer  transformedMetadataObjectForMetadataObject:face];
            UIView *faceView = [[UIView alloc] initWithFrame:tranformFace.bounds];
            faceView.layer.borderColor = [UIColor redColor].CGColor;
            faceView.layer.borderWidth = 1;
            [self->resultView addSubview:faceView];

        }
    });
}




- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    dispatch_sync(encodeQueue, ^{
        static int a =0;
        a ++;
        if (a % 4 == 0) {
            [self faceImagesByFaceRecognitionWithCIImage:sampleBuffer];
        }
       
    });
}


-(NSArray *)faceImagesByFaceRecognitionWithCIImage:(CMSampleBufferRef)sampleBuffer{
    
    CIContext * context = [CIContext contextWithOptions:nil];
    NSDictionary *param = @{CIDetectorAccuracy:CIDetectorAccuracyHigh,
                            CIDetectorTracking:@(YES),
                            
                            };
    
    CIDetector *faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:context options:param];
    
    
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *cImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    NSArray * detectResult = [faceDetector featuresInImage:cImage];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (self->resultView) {
            [self->resultView removeFromSuperview];
        }
        self->resultView = [[UIView alloc] initWithFrame:self.previewLayer.bounds];
        [self.view addSubview:self->resultView];
        
        for (CIFaceFeature * faceFeature in detectResult) {
            UIView *faceView = [[UIView alloc] initWithFrame:faceFeature.bounds];
            faceView.layer.borderColor = [UIColor redColor].CGColor;
            faceView.layer.borderWidth = 1;
            [self->resultView addSubview:faceView];
            
            
            if (faceFeature.hasLeftEyePosition) {
                UIView * leftEyeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
                [leftEyeView setCenter:faceFeature.leftEyePosition];
                leftEyeView.layer.borderWidth = 1;
                leftEyeView.layer.borderColor = [UIColor redColor].CGColor;
                [self->resultView addSubview:leftEyeView];
            }
            
            
            if (faceFeature.hasRightEyePosition) {
                UIView * rightEyeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
                [rightEyeView setCenter:faceFeature.rightEyePosition];
                rightEyeView.layer.borderWidth = 1;
                rightEyeView.layer.borderColor = [UIColor redColor].CGColor;
                [self->resultView addSubview:rightEyeView];
            }
            
            if (faceFeature.hasMouthPosition) {
                UIView * mouthView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 5)];
                [mouthView setCenter:faceFeature.mouthPosition];
                mouthView.layer.borderWidth = 1;
                mouthView.layer.borderColor = [UIColor redColor].CGColor;
                [self->resultView addSubview:mouthView];
            }
            
            
        }
        [self->resultView setTransform:CGAffineTransformMakeScale(1, -1)];
        
    });
    
    return nil;
}



#pragma mark - Getters

- (UIButton *)startBtn{
    if (!_startBtn) {
        _startBtn = [[UIButton alloc]initWithFrame:CGRectMake(220, 30, 100, 50)];
        [_startBtn setBackgroundColor:[UIColor cyanColor]];
        [_startBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [_startBtn setTitle:@"start" forState:UIControlStateNormal];
        [_startBtn addTarget:self action:@selector(startBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _startBtn;
}

- (UILabel *)titleLabel{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(50, 30, 150, 30)];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.text = @"测试H264编码";
    }
    return _titleLabel;
}

@end
