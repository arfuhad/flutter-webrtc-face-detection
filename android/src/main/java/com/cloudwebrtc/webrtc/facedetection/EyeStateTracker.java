package com.cloudwebrtc.webrtc.facedetection;

import java.util.HashMap;
import java.util.Map;

/**
 * Tracks eye state per face (by trackingId) to detect blinks.
 * A blink is detected when eye transitions from closed -> open.
 */
public class EyeStateTracker {

    public static class EyeState {
        public boolean wasOpen = true;
        public boolean isOpen = true;
        public int blinkCount = 0;
        /** Frame captured at the moment eye closed (to be emitted when blink completes) */
        public String pendingCapturedFrame = null;
    }

    public static class FaceEyeState {
        public EyeState leftEye = new EyeState();
        public EyeState rightEye = new EyeState();
    }

    public static class BlinkResult {
        public String eye; // "left", "right", or "both"
        public int leftBlinkCount;
        public int rightBlinkCount;
        public String capturedFrame; // base64 JPEG if captured

        public BlinkResult(String eye, int leftBlinkCount, int rightBlinkCount, String capturedFrame) {
            this.eye = eye;
            this.leftBlinkCount = leftBlinkCount;
            this.rightBlinkCount = rightBlinkCount;
            this.capturedFrame = capturedFrame;
        }

        public Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("eye", eye);
            map.put("leftBlinkCount", leftBlinkCount);
            map.put("rightBlinkCount", rightBlinkCount);
            if (capturedFrame != null) {
                map.put("capturedFrame", capturedFrame);
            }
            return map;
        }
    }

    // Map of trackingId -> FaceEyeState
    private final Map<Integer, FaceEyeState> faceStates = new HashMap<>();

    private double blinkThreshold = 0.3;

    public void setBlinkThreshold(double threshold) {
        this.blinkThreshold = threshold;
    }

    /**
     * Update eye state for a face and detect blinks.
     *
     * @param trackingId The face tracking ID
     * @param leftEyeOpenProb Left eye open probability (0.0-1.0)
     * @param rightEyeOpenProb Right eye open probability (0.0-1.0)
     * @param capturedFrame Base64 JPEG frame captured when eye closed (or null)
     * @return BlinkResult if a blink was detected, null otherwise
     */
    public BlinkResult updateEyeState(
            int trackingId,
            float leftEyeOpenProb,
            float rightEyeOpenProb,
            String capturedFrame
    ) {
        FaceEyeState faceState = faceStates.get(trackingId);
        if (faceState == null) {
            faceState = new FaceEyeState();
            faceStates.put(trackingId, faceState);
        }

        boolean leftCurrentlyOpen = leftEyeOpenProb > blinkThreshold;
        boolean rightCurrentlyOpen = rightEyeOpenProb > blinkThreshold;

        boolean leftBlinked = false;
        boolean rightBlinked = false;
        String blinkCapturedFrame = null;

        // Check left eye
        if (!faceState.leftEye.isOpen && leftCurrentlyOpen) {
            // Transition from closed to open = blink completed
            leftBlinked = true;
            faceState.leftEye.blinkCount++;
            blinkCapturedFrame = faceState.leftEye.pendingCapturedFrame;
            faceState.leftEye.pendingCapturedFrame = null;
        } else if (faceState.leftEye.isOpen && !leftCurrentlyOpen) {
            // Transition from open to closed = capture frame
            faceState.leftEye.pendingCapturedFrame = capturedFrame;
        }

        // Check right eye
        if (!faceState.rightEye.isOpen && rightCurrentlyOpen) {
            // Transition from closed to open = blink completed
            rightBlinked = true;
            faceState.rightEye.blinkCount++;
            if (blinkCapturedFrame == null) {
                blinkCapturedFrame = faceState.rightEye.pendingCapturedFrame;
            }
            faceState.rightEye.pendingCapturedFrame = null;
        } else if (faceState.rightEye.isOpen && !rightCurrentlyOpen) {
            // Transition from open to closed = capture frame
            faceState.rightEye.pendingCapturedFrame = capturedFrame;
        }

        // Update state
        faceState.leftEye.wasOpen = faceState.leftEye.isOpen;
        faceState.leftEye.isOpen = leftCurrentlyOpen;
        faceState.rightEye.wasOpen = faceState.rightEye.isOpen;
        faceState.rightEye.isOpen = rightCurrentlyOpen;

        // Return blink result if any eye blinked
        if (leftBlinked || rightBlinked) {
            String eye;
            if (leftBlinked && rightBlinked) {
                eye = "both";
            } else if (leftBlinked) {
                eye = "left";
            } else {
                eye = "right";
            }
            return new BlinkResult(
                    eye,
                    faceState.leftEye.blinkCount,
                    faceState.rightEye.blinkCount,
                    blinkCapturedFrame
            );
        }

        return null;
    }

    /**
     * Get the current eye state for a face.
     */
    public FaceEyeState getFaceState(int trackingId) {
        return faceStates.get(trackingId);
    }

    /**
     * Remove stale face states (faces no longer being tracked).
     */
    public void cleanupStaleStates(java.util.Set<Integer> activeTrackingIds) {
        faceStates.keySet().retainAll(activeTrackingIds);
    }

    /**
     * Clear all tracked states.
     */
    public void reset() {
        faceStates.clear();
    }
}
