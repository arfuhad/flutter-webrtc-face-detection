/// Which eye(s) blinked.
enum BlinkEye {
  left,
  right,
  both,
}

/// Represents a blink detection event.
class BlinkEvent {
  /// Which eye(s) blinked.
  final BlinkEye eye;

  /// Total blink count for the left eye since tracking started.
  final int leftBlinkCount;

  /// Total blink count for the right eye since tracking started.
  final int rightBlinkCount;

  /// Face tracking ID.
  final int? trackingId;

  /// Timestamp of the event in nanoseconds.
  final int? timestamp;

  /// Base64-encoded JPEG image captured at the moment of the blink.
  /// Only present if captureOnBlink was enabled in the config.
  final String? capturedFrame;

  const BlinkEvent({
    required this.eye,
    required this.leftBlinkCount,
    required this.rightBlinkCount,
    this.trackingId,
    this.timestamp,
    this.capturedFrame,
  });

  /// Total blink count (max of left and right).
  int get blinkCount =>
      leftBlinkCount > rightBlinkCount ? leftBlinkCount : rightBlinkCount;

  factory BlinkEvent.fromMap(Map<String, dynamic> map) {
    return BlinkEvent(
      eye: _parseBlinkEye(map['eye'] as String?),
      leftBlinkCount: map['leftBlinkCount'] as int? ?? 0,
      rightBlinkCount: map['rightBlinkCount'] as int? ?? 0,
      trackingId: map['trackingId'] as int?,
      timestamp: map['timestamp'] as int?,
      capturedFrame: map['capturedFrame'] as String?,
    );
  }

  static BlinkEye _parseBlinkEye(String? eye) {
    switch (eye) {
      case 'left':
        return BlinkEye.left;
      case 'right':
        return BlinkEye.right;
      case 'both':
        return BlinkEye.both;
      default:
        return BlinkEye.both;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'eye': eye.name,
      'leftBlinkCount': leftBlinkCount,
      'rightBlinkCount': rightBlinkCount,
      if (trackingId != null) 'trackingId': trackingId,
      if (timestamp != null) 'timestamp': timestamp,
      if (capturedFrame != null) 'capturedFrame': capturedFrame,
    };
  }

  @override
  String toString() =>
      'BlinkEvent(eye: ${eye.name}, leftCount: $leftBlinkCount, rightCount: $rightBlinkCount, trackingId: $trackingId)';
}
