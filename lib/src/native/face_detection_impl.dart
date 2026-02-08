import 'dart:async';

import '../face_detection/blink_event.dart';
import '../face_detection/face_detection_config.dart';
import '../face_detection/face_detection_result.dart';
import 'face_detection_event_channel.dart';
import 'media_stream_track_impl.dart';
import 'utils.dart';

/// Extension on MediaStreamTrackNative to add face detection capabilities.
extension FaceDetectionExtension on MediaStreamTrackNative {
  /// Enables face detection on this video track.
  ///
  /// [config] - Optional configuration for face detection.
  ///
  /// Throws an exception if the track is not a video track or if face detection
  /// is already enabled.
  Future<void> enableFaceDetection({FaceDetectionConfig? config}) async {
    if (kind != 'video') {
      throw Exception('Face detection can only be enabled on video tracks');
    }

    await WebRTC.invokeMethod('enableFaceDetection', {
      'trackId': id,
      'config': (config ?? const FaceDetectionConfig()).toMap(),
    });
  }

  /// Disables face detection on this video track.
  Future<void> disableFaceDetection() async {
    await WebRTC.invokeMethod('disableFaceDetection', {
      'trackId': id,
    });
  }

  /// Returns whether face detection is currently enabled on this track.
  Future<bool> isFaceDetectionEnabled() async {
    final result = await WebRTC.invokeMethod('isFaceDetectionEnabled', {
      'trackId': id,
    });
    return result as bool? ?? false;
  }

  /// Stream of face detection results.
  ///
  /// This stream emits [FaceDetectionResult] objects containing information
  /// about detected faces, including bounding boxes, landmarks, and head pose.
  ///
  /// The stream is shared across all video tracks - filter by track if needed.
  Stream<FaceDetectionResult> get onFaceDetected =>
      FaceDetectionEventChannel.instance.faceDetectionStream;

  /// Stream of blink events.
  ///
  /// This stream emits [BlinkEvent] objects when a blink is detected.
  /// A blink is registered when an eye transitions from closed to open.
  ///
  /// The stream is shared across all video tracks - filter by trackingId if needed.
  Stream<BlinkEvent> get onBlinkDetected =>
      FaceDetectionEventChannel.instance.blinkEventStream;
}
