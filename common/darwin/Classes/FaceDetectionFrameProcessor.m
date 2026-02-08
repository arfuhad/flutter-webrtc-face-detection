#import "FaceDetectionFrameProcessor.h"
#import <CoreVideo/CoreVideo.h>

@import MLKitFaceDetection;
@import MLKitVision;

#pragma mark - FaceDetectionConfig

@implementation FaceDetectionConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _frameSkipCount = 3;
        _blinkThreshold = 0.3;
        _captureOnBlink = NO;
        _cropToFace = YES;
        _imageQuality = 0.7;
        _maxImageWidth = 480;
    }
    return self;
}

+ (instancetype)configFromDictionary:(NSDictionary*)dict {
    FaceDetectionConfig* config = [[FaceDetectionConfig alloc] init];
    if (dict == nil) {
        return config;
    }

    if (dict[@"frameSkipCount"]) {
        config.frameSkipCount = [dict[@"frameSkipCount"] integerValue];
    }
    if (dict[@"blinkThreshold"]) {
        config.blinkThreshold = [dict[@"blinkThreshold"] doubleValue];
    }
    if (dict[@"captureOnBlink"]) {
        config.captureOnBlink = [dict[@"captureOnBlink"] boolValue];
    }
    if (dict[@"cropToFace"]) {
        config.cropToFace = [dict[@"cropToFace"] boolValue];
    }
    if (dict[@"imageQuality"]) {
        config.imageQuality = [dict[@"imageQuality"] doubleValue];
    }
    if (dict[@"maxImageWidth"]) {
        config.maxImageWidth = [dict[@"maxImageWidth"] integerValue];
    }

    return config;
}

@end

#pragma mark - EyeState

@implementation EyeState

- (instancetype)init {
    self = [super init];
    if (self) {
        _wasOpen = YES;
        _isOpen = YES;
        _blinkCount = 0;
        _pendingCapturedFrame = nil;
    }
    return self;
}

@end

#pragma mark - FaceEyeState

@implementation FaceEyeState

- (instancetype)init {
    self = [super init];
    if (self) {
        _leftEye = [[EyeState alloc] init];
        _rightEye = [[EyeState alloc] init];
    }
    return self;
}

@end

#pragma mark - EyeStateTracker

@interface EyeStateTracker ()
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, FaceEyeState*>* faceStates;
@property(nonatomic, assign) double blinkThreshold;
@end

@implementation EyeStateTracker

- (instancetype)init {
    self = [super init];
    if (self) {
        _faceStates = [NSMutableDictionary new];
        _blinkThreshold = 0.3;
    }
    return self;
}

- (void)setBlinkThreshold:(double)threshold {
    _blinkThreshold = threshold;
}

- (NSDictionary*)updateEyeStateForTrackingId:(NSInteger)trackingId
                             leftEyeOpenProb:(float)leftProb
                            rightEyeOpenProb:(float)rightProb
                               capturedFrame:(NSString*)capturedFrame {
    NSNumber* key = @(trackingId);
    FaceEyeState* faceState = _faceStates[key];
    if (faceState == nil) {
        faceState = [[FaceEyeState alloc] init];
        _faceStates[key] = faceState;
    }

    BOOL leftCurrentlyOpen = leftProb > _blinkThreshold;
    BOOL rightCurrentlyOpen = rightProb > _blinkThreshold;

    BOOL leftBlinked = NO;
    BOOL rightBlinked = NO;
    NSString* blinkCapturedFrame = nil;

    // Check left eye
    if (!faceState.leftEye.isOpen && leftCurrentlyOpen) {
        leftBlinked = YES;
        faceState.leftEye.blinkCount++;
        blinkCapturedFrame = faceState.leftEye.pendingCapturedFrame;
        faceState.leftEye.pendingCapturedFrame = nil;
    } else if (faceState.leftEye.isOpen && !leftCurrentlyOpen) {
        faceState.leftEye.pendingCapturedFrame = capturedFrame;
    }

    // Check right eye
    if (!faceState.rightEye.isOpen && rightCurrentlyOpen) {
        rightBlinked = YES;
        faceState.rightEye.blinkCount++;
        if (blinkCapturedFrame == nil) {
            blinkCapturedFrame = faceState.rightEye.pendingCapturedFrame;
        }
        faceState.rightEye.pendingCapturedFrame = nil;
    } else if (faceState.rightEye.isOpen && !rightCurrentlyOpen) {
        faceState.rightEye.pendingCapturedFrame = capturedFrame;
    }

    // Update state
    faceState.leftEye.wasOpen = faceState.leftEye.isOpen;
    faceState.leftEye.isOpen = leftCurrentlyOpen;
    faceState.rightEye.wasOpen = faceState.rightEye.isOpen;
    faceState.rightEye.isOpen = rightCurrentlyOpen;

    if (leftBlinked || rightBlinked) {
        NSString* eye;
        if (leftBlinked && rightBlinked) {
            eye = @"both";
        } else if (leftBlinked) {
            eye = @"left";
        } else {
            eye = @"right";
        }

        NSMutableDictionary* result = [NSMutableDictionary new];
        result[@"eye"] = eye;
        result[@"leftBlinkCount"] = @(faceState.leftEye.blinkCount);
        result[@"rightBlinkCount"] = @(faceState.rightEye.blinkCount);
        if (blinkCapturedFrame) {
            result[@"capturedFrame"] = blinkCapturedFrame;
        }
        return result;
    }

    return nil;
}

- (FaceEyeState*)getFaceState:(NSInteger)trackingId {
    return _faceStates[@(trackingId)];
}

- (void)cleanupStaleStates:(NSSet<NSNumber*>*)activeTrackingIds {
    NSMutableArray* keysToRemove = [NSMutableArray new];
    for (NSNumber* key in _faceStates) {
        if (![activeTrackingIds containsObject:key]) {
            [keysToRemove addObject:key];
        }
    }
    [_faceStates removeObjectsForKeys:keysToRemove];
}

- (void)reset {
    [_faceStates removeAllObjects];
}

@end

#pragma mark - FaceDetectionFrameProcessor

@interface FaceDetectionFrameProcessor ()
@property(nonatomic, strong) MLKFaceDetector* faceDetector;
@property(nonatomic, strong) EyeStateTracker* eyeStateTracker;
@property(nonatomic, strong) dispatch_queue_t processingQueue;
@property(nonatomic, assign) NSInteger frameCount;
@property(nonatomic, assign) BOOL isProcessing;
@property(nonatomic, assign) BOOL isDisposed;
@end

@implementation FaceDetectionFrameProcessor

- (instancetype)init {
    self = [super init];
    if (self) {
        // Configure ML Kit face detector
        MLKFaceDetectorOptions* options = [[MLKFaceDetectorOptions alloc] init];
        options.performanceMode = MLKFaceDetectorPerformanceModeFast;
        options.landmarkMode = MLKFaceDetectorLandmarkModeAll;
        options.classificationMode = MLKFaceDetectorClassificationModeAll;
        options.contourMode = MLKFaceDetectorContourModeNone;
        options.minFaceSize = 0.15;
        options.trackingEnabled = YES;

        _faceDetector = [MLKFaceDetector faceDetectorWithOptions:options];
        _eyeStateTracker = [[EyeStateTracker alloc] init];
        _config = [[FaceDetectionConfig alloc] init];
        _processingQueue = dispatch_queue_create("com.cloudwebrtc.facedetection", DISPATCH_QUEUE_SERIAL);
        _frameCount = 0;
        _isProcessing = NO;
        _isDisposed = NO;

        NSLog(@"FaceDetectionFrameProcessor initialized");
    }
    return self;
}

- (void)setConfig:(FaceDetectionConfig*)config {
    _config = config;
    [_eyeStateTracker setBlinkThreshold:config.blinkThreshold];
}

- (RTCVideoFrame*)onFrame:(RTCVideoFrame*)frame {
    if (_isDisposed) {
        return frame;
    }

    // Frame skip check
    _frameCount++;
    if (_frameCount % _config.frameSkipCount != 0) {
        return frame;
    }

    // Non-blocking check
    if (_isProcessing) {
        return frame;
    }
    _isProcessing = YES;

    // Retain frame data for async processing
    int64_t timestampNs = frame.timeStampNs;
    int width = frame.width;
    int height = frame.height;
    int rotation = frame.rotation;

    // Get the pixel buffer
    id<RTCVideoFrameBuffer> buffer = frame.buffer;
    CVPixelBufferRef pixelBuffer = NULL;

    if ([buffer isKindOfClass:[RTCCVPixelBuffer class]]) {
        RTCCVPixelBuffer* cvPixelBuffer = (RTCCVPixelBuffer*)buffer;
        pixelBuffer = cvPixelBuffer.pixelBuffer;
        CVPixelBufferRetain(pixelBuffer);
    }

    if (pixelBuffer == NULL) {
        _isProcessing = NO;
        return frame;
    }

    dispatch_async(_processingQueue, ^{
        if (self.isDisposed) {
            CVPixelBufferRelease(pixelBuffer);
            self.isProcessing = NO;
            return;
        }

        [self processPixelBuffer:pixelBuffer
                           width:width
                          height:height
                        rotation:rotation
                     timestampNs:timestampNs];

        CVPixelBufferRelease(pixelBuffer);
    });

    return frame;
}

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer
                     width:(int)width
                    height:(int)height
                  rotation:(int)rotation
               timestampNs:(int64_t)timestampNs {

    UIImageOrientation orientation;
    switch (rotation) {
        case 90:
            orientation = UIImageOrientationRight;
            break;
        case 180:
            orientation = UIImageOrientationDown;
            break;
        case 270:
            orientation = UIImageOrientationLeft;
            break;
        default:
            orientation = UIImageOrientationUp;
            break;
    }

    MLKVisionImage* visionImage = [[MLKVisionImage alloc] initWithBuffer:pixelBuffer];
    visionImage.orientation = orientation;

    [_faceDetector processImage:visionImage
                     completion:^(NSArray<MLKFace*>* _Nullable faces, NSError* _Nullable error) {
        if (self.isDisposed) {
            self.isProcessing = NO;
            return;
        }

        if (error) {
            NSLog(@"Face detection failed: %@", error.localizedDescription);
            self.isProcessing = NO;
            return;
        }

        [self processFaceResults:faces
                     pixelBuffer:pixelBuffer
                           width:width
                          height:height
                        rotation:rotation
                     timestampNs:timestampNs];

        self.isProcessing = NO;
    }];
}

- (void)processFaceResults:(NSArray<MLKFace*>*)faces
               pixelBuffer:(CVPixelBufferRef)pixelBuffer
                     width:(int)width
                    height:(int)height
                  rotation:(int)rotation
               timestampNs:(int64_t)timestampNs {

    if (_faceEventSink == nil && _blinkEventSink == nil) {
        return;
    }

    NSMutableSet<NSNumber*>* activeTrackingIds = [NSMutableSet new];
    NSMutableArray* faceDataList = [NSMutableArray new];

    for (MLKFace* face in faces) {
        NSInteger trackingId = face.trackingID;
        [activeTrackingIds addObject:@(trackingId)];

        NSMutableDictionary* faceData = [NSMutableDictionary new];

        // Bounds
        CGRect bounds = face.frame;
        faceData[@"bounds"] = @{
            @"left": @(bounds.origin.x),
            @"top": @(bounds.origin.y),
            @"width": @(bounds.size.width),
            @"height": @(bounds.size.height)
        };

        // Tracking ID
        if (face.hasTrackingID) {
            faceData[@"trackingId"] = @(trackingId);
        }

        // Head pose
        faceData[@"headPose"] = @{
            @"yaw": @(face.headEulerAngleY),
            @"pitch": @(face.headEulerAngleX),
            @"roll": @(face.headEulerAngleZ)
        };

        // Landmarks
        NSMutableDictionary* landmarks = [NSMutableDictionary new];

        // Left eye
        MLKFaceLandmark* leftEye = [face landmarkOfType:MLKFaceLandmarkTypeLeftEye];
        if (leftEye) {
            NSMutableDictionary* leftEyeData = [NSMutableDictionary new];
            leftEyeData[@"x"] = @(leftEye.position.x);
            leftEyeData[@"y"] = @(leftEye.position.y);
            if (face.hasLeftEyeOpenProbability) {
                leftEyeData[@"openProbability"] = @(face.leftEyeOpenProbability);
                leftEyeData[@"isOpen"] = @(face.leftEyeOpenProbability > _config.blinkThreshold);
            }
            landmarks[@"leftEye"] = leftEyeData;
        }

        // Right eye
        MLKFaceLandmark* rightEye = [face landmarkOfType:MLKFaceLandmarkTypeRightEye];
        if (rightEye) {
            NSMutableDictionary* rightEyeData = [NSMutableDictionary new];
            rightEyeData[@"x"] = @(rightEye.position.x);
            rightEyeData[@"y"] = @(rightEye.position.y);
            if (face.hasRightEyeOpenProbability) {
                rightEyeData[@"openProbability"] = @(face.rightEyeOpenProbability);
                rightEyeData[@"isOpen"] = @(face.rightEyeOpenProbability > _config.blinkThreshold);
            }
            landmarks[@"rightEye"] = rightEyeData;
        }

        // Nose
        MLKFaceLandmark* nose = [face landmarkOfType:MLKFaceLandmarkTypeNoseBase];
        if (nose) {
            landmarks[@"nose"] = @{
                @"x": @(nose.position.x),
                @"y": @(nose.position.y)
            };
        }

        // Mouth
        MLKFaceLandmark* mouthLeft = [face landmarkOfType:MLKFaceLandmarkTypeMouthLeft];
        MLKFaceLandmark* mouthRight = [face landmarkOfType:MLKFaceLandmarkTypeMouthRight];
        MLKFaceLandmark* mouthBottom = [face landmarkOfType:MLKFaceLandmarkTypeMouthBottom];
        if (mouthLeft && mouthRight) {
            NSMutableDictionary* mouthData = [NSMutableDictionary new];
            mouthData[@"leftX"] = @(mouthLeft.position.x);
            mouthData[@"leftY"] = @(mouthLeft.position.y);
            mouthData[@"rightX"] = @(mouthRight.position.x);
            mouthData[@"rightY"] = @(mouthRight.position.y);
            if (mouthBottom) {
                mouthData[@"bottomX"] = @(mouthBottom.position.x);
                mouthData[@"bottomY"] = @(mouthBottom.position.y);
            }
            if (face.hasSmilingProbability) {
                mouthData[@"smilingProbability"] = @(face.smilingProbability);
            }
            landmarks[@"mouth"] = mouthData;
        }

        faceData[@"landmarks"] = landmarks;

        // Smiling probability
        if (face.hasSmilingProbability) {
            faceData[@"smilingProbability"] = @(face.smilingProbability);
        }

        [faceDataList addObject:faceData];

        // Blink detection
        if (face.hasTrackingID && _blinkEventSink != nil) {
            if (face.hasLeftEyeOpenProbability && face.hasRightEyeOpenProbability) {
                NSString* capturedFrame = nil;

                if (_config.captureOnBlink) {
                    BOOL leftClosing = face.leftEyeOpenProbability <= _config.blinkThreshold;
                    BOOL rightClosing = face.rightEyeOpenProbability <= _config.blinkThreshold;
                    FaceEyeState* faceState = [_eyeStateTracker getFaceState:trackingId];
                    BOOL wasLeftOpen = faceState == nil || faceState.leftEye.isOpen;
                    BOOL wasRightOpen = faceState == nil || faceState.rightEye.isOpen;

                    if ((leftClosing && wasLeftOpen) || (rightClosing && wasRightOpen)) {
                        capturedFrame = [self captureFrameAsBase64:pixelBuffer
                                                            width:width
                                                           height:height
                                                       faceBounds:bounds];
                    }
                }

                NSDictionary* blinkResult = [_eyeStateTracker updateEyeStateForTrackingId:trackingId
                                                                          leftEyeOpenProb:face.leftEyeOpenProbability
                                                                         rightEyeOpenProb:face.rightEyeOpenProbability
                                                                            capturedFrame:capturedFrame];

                if (blinkResult) {
                    NSMutableDictionary* blinkEvent = [blinkResult mutableCopy];
                    blinkEvent[@"trackingId"] = @(trackingId);
                    blinkEvent[@"timestamp"] = @(timestampNs);
                    [self emitBlinkEvent:blinkEvent];
                }
            }
        }
    }

    // Cleanup stale face states
    [_eyeStateTracker cleanupStaleStates:activeTrackingIds];

    // Emit face detection results
    if (_faceEventSink != nil) {
        NSDictionary* result = @{
            @"faces": faceDataList,
            @"timestamp": @(timestampNs),
            @"frameWidth": @(width),
            @"frameHeight": @(height)
        };
        [self emitFaceEvent:result];
    }
}

- (void)emitFaceEvent:(NSDictionary*)event {
    if (_faceEventSink == nil || _isDisposed) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.faceEventSink != nil && !self.isDisposed) {
            self.faceEventSink(event);
        }
    });
}

- (void)emitBlinkEvent:(NSDictionary*)event {
    if (_blinkEventSink == nil || _isDisposed) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.blinkEventSink != nil && !self.isDisposed) {
            self.blinkEventSink(event);
        }
    });
}

- (NSString*)captureFrameAsBase64:(CVPixelBufferRef)pixelBuffer
                            width:(int)width
                           height:(int)height
                       faceBounds:(CGRect)faceBounds {
    @try {
        CIImage* ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];

        CGRect cropRect;
        if (_config.cropToFace && !CGRectIsEmpty(faceBounds)) {
            CGFloat padding = MIN(faceBounds.size.width, faceBounds.size.height) * 0.2;
            cropRect = CGRectMake(
                MAX(0, faceBounds.origin.x - padding),
                MAX(0, faceBounds.origin.y - padding),
                MIN(width - faceBounds.origin.x + padding, faceBounds.size.width + padding * 2),
                MIN(height - faceBounds.origin.y + padding, faceBounds.size.height + padding * 2)
            );
        } else {
            cropRect = CGRectMake(0, 0, width, height);
        }

        ciImage = [ciImage imageByCroppingToRect:cropRect];

        CIContext* context = [CIContext contextWithOptions:nil];
        CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];

        if (cgImage == NULL) {
            return nil;
        }

        UIImage* image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);

        // Resize if necessary
        if (_config.maxImageWidth > 0 && image.size.width > _config.maxImageWidth) {
            CGFloat scale = _config.maxImageWidth / image.size.width;
            CGSize newSize = CGSizeMake(_config.maxImageWidth, image.size.height * scale);

            UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
            [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }

        NSData* jpegData = UIImageJPEGRepresentation(image, _config.imageQuality);
        return [jpegData base64EncodedStringWithOptions:0];

    } @catch (NSException* exception) {
        NSLog(@"Error capturing frame: %@", exception.reason);
        return nil;
    }
}

- (void)dispose {
    _isDisposed = YES;
    _isProcessing = NO;
    [_eyeStateTracker reset];
    _faceEventSink = nil;
    _blinkEventSink = nil;

    NSLog(@"FaceDetectionFrameProcessor disposed");
}

@end
