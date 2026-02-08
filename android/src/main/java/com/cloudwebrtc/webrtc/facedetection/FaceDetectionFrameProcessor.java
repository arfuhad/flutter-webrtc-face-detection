package com.cloudwebrtc.webrtc.facedetection;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;

import com.cloudwebrtc.webrtc.video.LocalVideoTrack;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.face.Face;
import com.google.mlkit.vision.face.FaceDetection;
import com.google.mlkit.vision.face.FaceDetector;
import com.google.mlkit.vision.face.FaceDetectorOptions;
import com.google.mlkit.vision.face.FaceLandmark;

import org.webrtc.VideoFrame;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.plugin.common.EventChannel;

/**
 * Processes video frames for face detection using ML Kit.
 * Implements LocalVideoTrack.ExternalVideoFrameProcessing to receive frames from WebRTC.
 */
public class FaceDetectionFrameProcessor implements LocalVideoTrack.ExternalVideoFrameProcessing {
    private static final String TAG = "FaceDetection";

    private final FaceDetector faceDetector;
    private final EyeStateTracker eyeStateTracker;
    private final Handler processingHandler;
    private final HandlerThread processingThread;

    private EventChannel.EventSink faceEventSink;
    private EventChannel.EventSink blinkEventSink;

    private FaceDetectionConfig config;
    private int frameCount = 0;
    private volatile boolean isProcessing = false;
    private volatile boolean isDisposed = false;

    public FaceDetectionFrameProcessor() {
        // Configure ML Kit face detector
        FaceDetectorOptions options = new FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
                .setMinFaceSize(0.15f)
                .enableTracking()
                .build();

        faceDetector = FaceDetection.getClient(options);
        eyeStateTracker = new EyeStateTracker();
        config = new FaceDetectionConfig();

        // Create dedicated processing thread
        processingThread = new HandlerThread("FaceDetectionThread");
        processingThread.start();
        processingHandler = new Handler(processingThread.getLooper());

        Log.d(TAG, "FaceDetectionFrameProcessor initialized");
    }

    public void setConfig(FaceDetectionConfig config) {
        this.config = config;
        eyeStateTracker.setBlinkThreshold(config.blinkThreshold);
    }

    public void setFaceEventSink(EventChannel.EventSink sink) {
        this.faceEventSink = sink;
    }

    public void setBlinkEventSink(EventChannel.EventSink sink) {
        this.blinkEventSink = sink;
    }

    @Override
    public VideoFrame onFrame(VideoFrame frame) {
        if (isDisposed) {
            return frame;
        }

        // Frame skip check
        frameCount++;
        if (frameCount % config.frameSkipCount != 0) {
            return frame;
        }

        // Non-blocking check - skip if still processing previous frame
        if (isProcessing) {
            return frame;
        }
        isProcessing = true;

        // Capture frame data before async processing
        final int width = frame.getBuffer().getWidth();
        final int height = frame.getBuffer().getHeight();
        final int rotation = frame.getRotation();
        final long timestampNs = frame.getTimestampNs();

        // Convert to I420 and copy data
        VideoFrame.I420Buffer i420Buffer = frame.getBuffer().toI420();
        final byte[] nv21Data = convertI420ToNV21(i420Buffer, width, height);
        i420Buffer.release();

        // Process asynchronously
        processingHandler.post(() -> {
            if (isDisposed) {
                isProcessing = false;
                return;
            }
            processFrameAsync(nv21Data, width, height, rotation, timestampNs);
        });

        return frame; // Return original frame for rendering
    }

    private void processFrameAsync(byte[] nv21Data, int width, int height, int rotation, long timestampNs) {
        try {
            // Create InputImage from NV21 data
            InputImage inputImage = InputImage.fromByteArray(
                    nv21Data,
                    width,
                    height,
                    rotation,
                    InputImage.IMAGE_FORMAT_NV21
            );

            // Run face detection
            faceDetector.process(inputImage)
                    .addOnSuccessListener(faces -> {
                        if (isDisposed) {
                            isProcessing = false;
                            return;
                        }
                        processFaceResults(faces, nv21Data, width, height, rotation, timestampNs);
                        isProcessing = false;
                    })
                    .addOnFailureListener(e -> {
                        Log.e(TAG, "Face detection failed", e);
                        isProcessing = false;
                    });

        } catch (Exception e) {
            Log.e(TAG, "Error processing frame", e);
            isProcessing = false;
        }
    }

    private void processFaceResults(List<Face> faces, byte[] nv21Data, int width, int height, int rotation, long timestampNs) {
        if (faceEventSink == null && blinkEventSink == null) {
            return;
        }

        Set<Integer> activeTrackingIds = new HashSet<>();
        List<Map<String, Object>> faceDataList = new ArrayList<>();

        for (Face face : faces) {
            Integer trackingId = face.getTrackingId();
            if (trackingId != null) {
                activeTrackingIds.add(trackingId);
            }

            Map<String, Object> faceData = new HashMap<>();

            // Bounds
            Rect bounds = face.getBoundingBox();
            Map<String, Object> boundsMap = new HashMap<>();
            boundsMap.put("left", bounds.left);
            boundsMap.put("top", bounds.top);
            boundsMap.put("width", bounds.width());
            boundsMap.put("height", bounds.height());
            faceData.put("bounds", boundsMap);

            // Tracking ID
            if (trackingId != null) {
                faceData.put("trackingId", trackingId);
            }

            // Head pose
            Map<String, Object> headPose = new HashMap<>();
            headPose.put("yaw", face.getHeadEulerAngleY());
            headPose.put("pitch", face.getHeadEulerAngleX());
            headPose.put("roll", face.getHeadEulerAngleZ());
            faceData.put("headPose", headPose);

            // Landmarks
            Map<String, Object> landmarks = new HashMap<>();

            // Left eye
            FaceLandmark leftEye = face.getLandmark(FaceLandmark.LEFT_EYE);
            if (leftEye != null) {
                Map<String, Object> leftEyeData = new HashMap<>();
                leftEyeData.put("x", leftEye.getPosition().x);
                leftEyeData.put("y", leftEye.getPosition().y);
                Float leftEyeOpenProb = face.getLeftEyeOpenProbability();
                if (leftEyeOpenProb != null) {
                    leftEyeData.put("openProbability", leftEyeOpenProb);
                    leftEyeData.put("isOpen", leftEyeOpenProb > config.blinkThreshold);
                }
                landmarks.put("leftEye", leftEyeData);
            }

            // Right eye
            FaceLandmark rightEye = face.getLandmark(FaceLandmark.RIGHT_EYE);
            if (rightEye != null) {
                Map<String, Object> rightEyeData = new HashMap<>();
                rightEyeData.put("x", rightEye.getPosition().x);
                rightEyeData.put("y", rightEye.getPosition().y);
                Float rightEyeOpenProb = face.getRightEyeOpenProbability();
                if (rightEyeOpenProb != null) {
                    rightEyeData.put("openProbability", rightEyeOpenProb);
                    rightEyeData.put("isOpen", rightEyeOpenProb > config.blinkThreshold);
                }
                landmarks.put("rightEye", rightEyeData);
            }

            // Nose
            FaceLandmark nose = face.getLandmark(FaceLandmark.NOSE_BASE);
            if (nose != null) {
                Map<String, Object> noseData = new HashMap<>();
                noseData.put("x", nose.getPosition().x);
                noseData.put("y", nose.getPosition().y);
                landmarks.put("nose", noseData);
            }

            // Mouth
            FaceLandmark mouthLeft = face.getLandmark(FaceLandmark.MOUTH_LEFT);
            FaceLandmark mouthRight = face.getLandmark(FaceLandmark.MOUTH_RIGHT);
            FaceLandmark mouthBottom = face.getLandmark(FaceLandmark.MOUTH_BOTTOM);
            if (mouthLeft != null && mouthRight != null) {
                Map<String, Object> mouthData = new HashMap<>();
                mouthData.put("leftX", mouthLeft.getPosition().x);
                mouthData.put("leftY", mouthLeft.getPosition().y);
                mouthData.put("rightX", mouthRight.getPosition().x);
                mouthData.put("rightY", mouthRight.getPosition().y);
                if (mouthBottom != null) {
                    mouthData.put("bottomX", mouthBottom.getPosition().x);
                    mouthData.put("bottomY", mouthBottom.getPosition().y);
                }
                Float smilingProb = face.getSmilingProbability();
                if (smilingProb != null) {
                    mouthData.put("smilingProbability", smilingProb);
                }
                landmarks.put("mouth", mouthData);
            }

            faceData.put("landmarks", landmarks);

            // Smiling probability
            Float smilingProb = face.getSmilingProbability();
            if (smilingProb != null) {
                faceData.put("smilingProbability", smilingProb);
            }

            faceDataList.add(faceData);

            // Blink detection
            if (trackingId != null && blinkEventSink != null) {
                Float leftEyeOpenProb = face.getLeftEyeOpenProbability();
                Float rightEyeOpenProb = face.getRightEyeOpenProbability();

                if (leftEyeOpenProb != null && rightEyeOpenProb != null) {
                    // Capture frame if configured and eye is closing
                    String capturedFrame = null;
                    if (config.captureOnBlink) {
                        boolean leftClosing = leftEyeOpenProb <= config.blinkThreshold;
                        boolean rightClosing = rightEyeOpenProb <= config.blinkThreshold;
                        EyeStateTracker.FaceEyeState faceState = eyeStateTracker.getFaceState(trackingId);
                        boolean wasLeftOpen = faceState == null || faceState.leftEye.isOpen;
                        boolean wasRightOpen = faceState == null || faceState.rightEye.isOpen;

                        if ((leftClosing && wasLeftOpen) || (rightClosing && wasRightOpen)) {
                            capturedFrame = captureFrameAsBase64(nv21Data, width, height, bounds);
                        }
                    }

                    EyeStateTracker.BlinkResult blinkResult = eyeStateTracker.updateEyeState(
                            trackingId,
                            leftEyeOpenProb,
                            rightEyeOpenProb,
                            capturedFrame
                    );

                    if (blinkResult != null) {
                        Map<String, Object> blinkEvent = blinkResult.toMap();
                        blinkEvent.put("trackingId", trackingId);
                        blinkEvent.put("timestamp", timestampNs);
                        emitBlinkEvent(blinkEvent);
                    }
                }
            }
        }

        // Cleanup stale face states
        eyeStateTracker.cleanupStaleStates(activeTrackingIds);

        // Emit face detection results
        if (faceEventSink != null) {
            Map<String, Object> result = new HashMap<>();
            result.put("faces", faceDataList);
            result.put("timestamp", timestampNs);
            result.put("frameWidth", width);
            result.put("frameHeight", height);
            emitFaceEvent(result);
        }
    }

    private void emitFaceEvent(Map<String, Object> event) {
        if (faceEventSink != null) {
            try {
                // Must emit on main thread
                new Handler(android.os.Looper.getMainLooper()).post(() -> {
                    if (faceEventSink != null && !isDisposed) {
                        faceEventSink.success(event);
                    }
                });
            } catch (Exception e) {
                Log.e(TAG, "Error emitting face event", e);
            }
        }
    }

    private void emitBlinkEvent(Map<String, Object> event) {
        if (blinkEventSink != null) {
            try {
                // Must emit on main thread
                new Handler(android.os.Looper.getMainLooper()).post(() -> {
                    if (blinkEventSink != null && !isDisposed) {
                        blinkEventSink.success(event);
                    }
                });
            } catch (Exception e) {
                Log.e(TAG, "Error emitting blink event", e);
            }
        }
    }

    private String captureFrameAsBase64(byte[] nv21Data, int width, int height, Rect faceBounds) {
        try {
            // Convert NV21 to JPEG
            YuvImage yuvImage = new YuvImage(nv21Data, ImageFormat.NV21, width, height, null);
            ByteArrayOutputStream jpegStream = new ByteArrayOutputStream();

            Rect cropRect;
            if (config.cropToFace && faceBounds != null) {
                // Expand face bounds slightly for context
                int padding = (int) (Math.min(faceBounds.width(), faceBounds.height()) * 0.2);
                cropRect = new Rect(
                        Math.max(0, faceBounds.left - padding),
                        Math.max(0, faceBounds.top - padding),
                        Math.min(width, faceBounds.right + padding),
                        Math.min(height, faceBounds.bottom + padding)
                );
            } else {
                cropRect = new Rect(0, 0, width, height);
            }

            int quality = (int) (config.imageQuality * 100);
            yuvImage.compressToJpeg(cropRect, quality, jpegStream);

            byte[] jpegBytes = jpegStream.toByteArray();

            // Resize if necessary
            if (config.maxImageWidth > 0 && cropRect.width() > config.maxImageWidth) {
                Bitmap bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.length);
                float scale = (float) config.maxImageWidth / bitmap.getWidth();
                int newHeight = (int) (bitmap.getHeight() * scale);

                Bitmap resized = Bitmap.createScaledBitmap(bitmap, config.maxImageWidth, newHeight, true);
                bitmap.recycle();

                ByteArrayOutputStream resizedStream = new ByteArrayOutputStream();
                resized.compress(Bitmap.CompressFormat.JPEG, quality, resizedStream);
                resized.recycle();

                jpegBytes = resizedStream.toByteArray();
            }

            return Base64.encodeToString(jpegBytes, Base64.NO_WRAP);
        } catch (Exception e) {
            Log.e(TAG, "Error capturing frame", e);
            return null;
        }
    }

    /**
     * Convert I420 buffer to NV21 byte array.
     */
    private byte[] convertI420ToNV21(VideoFrame.I420Buffer i420Buffer, int width, int height) {
        int chromaWidth = (width + 1) / 2;
        int chromaHeight = (height + 1) / 2;

        int ySize = width * height;
        int uvSize = chromaWidth * chromaHeight * 2;
        byte[] nv21 = new byte[ySize + uvSize];

        // Copy Y plane
        ByteBuffer yBuffer = i420Buffer.getDataY();
        int yStride = i420Buffer.getStrideY();
        for (int row = 0; row < height; row++) {
            yBuffer.position(row * yStride);
            yBuffer.get(nv21, row * width, width);
        }

        // Interleave U and V planes to VU (NV21 format)
        ByteBuffer uBuffer = i420Buffer.getDataU();
        ByteBuffer vBuffer = i420Buffer.getDataV();
        int uStride = i420Buffer.getStrideU();
        int vStride = i420Buffer.getStrideV();

        int uvOffset = ySize;
        for (int row = 0; row < chromaHeight; row++) {
            for (int col = 0; col < chromaWidth; col++) {
                int uIndex = row * uStride + col;
                int vIndex = row * vStride + col;
                nv21[uvOffset++] = vBuffer.get(vIndex); // V first in NV21
                nv21[uvOffset++] = uBuffer.get(uIndex); // then U
            }
        }

        return nv21;
    }

    public void dispose() {
        isDisposed = true;
        isProcessing = false;

        processingHandler.post(() -> {
            faceDetector.close();
            eyeStateTracker.reset();
        });

        processingThread.quitSafely();

        faceEventSink = null;
        blinkEventSink = null;

        Log.d(TAG, "FaceDetectionFrameProcessor disposed");
    }
}
