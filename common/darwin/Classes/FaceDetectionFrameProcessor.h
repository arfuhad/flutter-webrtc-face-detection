#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
#import "VideoProcessingAdapter.h"

#if TARGET_OS_IPHONE
#import <Flutter/Flutter.h>
#elif TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#endif

@import MLKitFaceDetection;
@import MLKitVision;

NS_ASSUME_NONNULL_BEGIN

@interface FaceDetectionConfig : NSObject

@property(nonatomic, assign) NSInteger frameSkipCount;
@property(nonatomic, assign) double blinkThreshold;
@property(nonatomic, assign) BOOL captureOnBlink;
@property(nonatomic, assign) BOOL cropToFace;
@property(nonatomic, assign) double imageQuality;
@property(nonatomic, assign) NSInteger maxImageWidth;

+ (instancetype)configFromDictionary:(NSDictionary* _Nullable)dict;

@end

@interface EyeState : NSObject

@property(nonatomic, assign) BOOL wasOpen;
@property(nonatomic, assign) BOOL isOpen;
@property(nonatomic, assign) NSInteger blinkCount;
@property(nonatomic, strong, nullable) NSString* pendingCapturedFrame;

@end

@interface FaceEyeState : NSObject

@property(nonatomic, strong) EyeState* leftEye;
@property(nonatomic, strong) EyeState* rightEye;

@end

@interface EyeStateTracker : NSObject

- (void)setBlinkThreshold:(double)threshold;
- (NSDictionary* _Nullable)updateEyeStateForTrackingId:(NSInteger)trackingId
                                       leftEyeOpenProb:(float)leftProb
                                      rightEyeOpenProb:(float)rightProb
                                         capturedFrame:(NSString* _Nullable)capturedFrame;
- (FaceEyeState* _Nullable)getFaceState:(NSInteger)trackingId;
- (void)cleanupStaleStates:(NSSet<NSNumber*>*)activeTrackingIds;
- (void)reset;

@end

@interface FaceDetectionFrameProcessor : NSObject <ExternalVideoProcessingDelegate>

@property(nonatomic, weak, nullable) FlutterEventSink faceEventSink;
@property(nonatomic, weak, nullable) FlutterEventSink blinkEventSink;
@property(nonatomic, strong) FaceDetectionConfig* config;

- (instancetype)init;
- (void)setConfig:(FaceDetectionConfig*)config;
- (void)dispose;

@end

NS_ASSUME_NONNULL_END
