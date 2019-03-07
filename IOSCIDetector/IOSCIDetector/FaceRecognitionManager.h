

#import <UIKit/UIKit.h>

@interface FaceRecognitionManager : NSObject

/**
 *  通过人脸识别提取有效人脸图片
 *
 *  @param image 待识别图片
 *
 *  @return 有效人脸图片集合
 */
+(NSArray *)faceImagesByFaceRecognitionWithImage:(UIImage *)image;


/**
 *  通过人脸识别得出有效人脸数
 *
 *  @param image 待识别图片
 *
 *  @return 有效人脸个数
 */
+(NSInteger)totalNumberOfFacesByFaceRecognitionWithImage:(UIImage *)image;

@end
