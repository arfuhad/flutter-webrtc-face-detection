import 'dart:async';

import 'package:flutter/services.dart';

import '../face_detection/blink_event.dart';
import '../face_detection/face_detection_result.dart';

/// Handles EventChannel communication for face detection events.
class FaceDetectionEventChannel {
  static const String _faceEventsChannel = 'FlutterWebRTC/faceDetection/faces';
  static const String _blinkEventsChannel = 'FlutterWebRTC/faceDetection/blinks';

  FaceDetectionEventChannel._internal() {
    _initializeFaceEventChannel();
    _initializeBlinkEventChannel();
  }

  static final FaceDetectionEventChannel instance =
      FaceDetectionEventChannel._internal();

  StreamController<FaceDetectionResult>? _faceDetectionController;
  StreamController<BlinkEvent>? _blinkEventController;

  StreamSubscription<dynamic>? _faceEventSubscription;
  StreamSubscription<dynamic>? _blinkEventSubscription;

  void _initializeFaceEventChannel() {
    _faceDetectionController = StreamController<FaceDetectionResult>.broadcast(
      onListen: () {
        _faceEventSubscription ??= const EventChannel(_faceEventsChannel)
            .receiveBroadcastStream()
            .listen(
          (dynamic event) {
            if (event is Map) {
              try {
                final result = FaceDetectionResult.fromMap(
                  Map<String, dynamic>.from(event),
                );
                _faceDetectionController?.add(result);
              } catch (e) {
                _faceDetectionController?.addError(e);
              }
            }
          },
          onError: (dynamic error) {
            _faceDetectionController?.addError(error);
          },
        );
      },
      onCancel: () {
        // Keep the subscription alive - don't cancel on individual listener cancel
        // The native side manages the lifecycle
      },
    );
  }

  void _initializeBlinkEventChannel() {
    _blinkEventController = StreamController<BlinkEvent>.broadcast(
      onListen: () {
        _blinkEventSubscription ??= const EventChannel(_blinkEventsChannel)
            .receiveBroadcastStream()
            .listen(
          (dynamic event) {
            if (event is Map) {
              try {
                final blinkEvent = BlinkEvent.fromMap(
                  Map<String, dynamic>.from(event),
                );
                _blinkEventController?.add(blinkEvent);
              } catch (e) {
                _blinkEventController?.addError(e);
              }
            }
          },
          onError: (dynamic error) {
            _blinkEventController?.addError(error);
          },
        );
      },
      onCancel: () {
        // Keep the subscription alive
      },
    );
  }

  /// Stream of face detection results.
  Stream<FaceDetectionResult> get faceDetectionStream =>
      _faceDetectionController?.stream ?? const Stream.empty();

  /// Stream of blink events.
  Stream<BlinkEvent> get blinkEventStream =>
      _blinkEventController?.stream ?? const Stream.empty();

  /// Dispose of all resources.
  void dispose() {
    _faceEventSubscription?.cancel();
    _blinkEventSubscription?.cancel();
    _faceDetectionController?.close();
    _blinkEventController?.close();
    _faceEventSubscription = null;
    _blinkEventSubscription = null;
    _faceDetectionController = null;
    _blinkEventController = null;
  }
}
