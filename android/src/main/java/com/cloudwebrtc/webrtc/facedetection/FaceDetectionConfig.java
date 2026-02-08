package com.cloudwebrtc.webrtc.facedetection;

import java.util.Map;

/**
 * Configuration for face detection processing.
 */
public class FaceDetectionConfig {
    /** Process every Nth frame (default: 3 = ~10 detections/sec at 30fps) */
    public int frameSkipCount = 3;

    /** Eye open probability threshold for blink detection (0.0-1.0) */
    public double blinkThreshold = 0.3;

    /** Whether to capture a frame when blink is detected */
    public boolean captureOnBlink = false;

    /** Whether to crop captured image to face bounds */
    public boolean cropToFace = true;

    /** JPEG quality for captured images (0.0-1.0) */
    public double imageQuality = 0.7;

    /** Maximum width for captured images in pixels */
    public int maxImageWidth = 480;

    public FaceDetectionConfig() {}

    public static FaceDetectionConfig fromMap(Map<String, Object> map) {
        FaceDetectionConfig config = new FaceDetectionConfig();

        if (map == null) {
            return config;
        }

        if (map.containsKey("frameSkipCount")) {
            Object value = map.get("frameSkipCount");
            if (value instanceof Number) {
                config.frameSkipCount = ((Number) value).intValue();
            }
        }

        if (map.containsKey("blinkThreshold")) {
            Object value = map.get("blinkThreshold");
            if (value instanceof Number) {
                config.blinkThreshold = ((Number) value).doubleValue();
            }
        }

        if (map.containsKey("captureOnBlink")) {
            Object value = map.get("captureOnBlink");
            if (value instanceof Boolean) {
                config.captureOnBlink = (Boolean) value;
            }
        }

        if (map.containsKey("cropToFace")) {
            Object value = map.get("cropToFace");
            if (value instanceof Boolean) {
                config.cropToFace = (Boolean) value;
            }
        }

        if (map.containsKey("imageQuality")) {
            Object value = map.get("imageQuality");
            if (value instanceof Number) {
                config.imageQuality = ((Number) value).doubleValue();
            }
        }

        if (map.containsKey("maxImageWidth")) {
            Object value = map.get("maxImageWidth");
            if (value instanceof Number) {
                config.maxImageWidth = ((Number) value).intValue();
            }
        }

        return config;
    }
}
