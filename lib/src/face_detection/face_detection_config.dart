/// Configuration for face detection processing.
class FaceDetectionConfig {
  /// Process every Nth frame (default: 3 = ~10 detections/sec at 30fps).
  final int frameSkipCount;

  /// Eye open probability threshold for blink detection (0.0-1.0).
  final double blinkThreshold;

  /// Whether to capture a frame when blink is detected.
  final bool captureOnBlink;

  /// Whether to crop captured image to face bounds.
  final bool cropToFace;

  /// JPEG quality for captured images (0.0-1.0).
  final double imageQuality;

  /// Maximum width for captured images in pixels.
  final int maxImageWidth;

  const FaceDetectionConfig({
    this.frameSkipCount = 3,
    this.blinkThreshold = 0.3,
    this.captureOnBlink = false,
    this.cropToFace = true,
    this.imageQuality = 0.7,
    this.maxImageWidth = 480,
  });

  /// Converts the config to a map for platform channel communication.
  Map<String, dynamic> toMap() {
    return {
      'frameSkipCount': frameSkipCount,
      'blinkThreshold': blinkThreshold,
      'captureOnBlink': captureOnBlink,
      'cropToFace': cropToFace,
      'imageQuality': imageQuality,
      'maxImageWidth': maxImageWidth,
    };
  }

  /// Creates a config from a map (for receiving from platform).
  factory FaceDetectionConfig.fromMap(Map<String, dynamic> map) {
    return FaceDetectionConfig(
      frameSkipCount: map['frameSkipCount'] as int? ?? 3,
      blinkThreshold: (map['blinkThreshold'] as num?)?.toDouble() ?? 0.3,
      captureOnBlink: map['captureOnBlink'] as bool? ?? false,
      cropToFace: map['cropToFace'] as bool? ?? true,
      imageQuality: (map['imageQuality'] as num?)?.toDouble() ?? 0.7,
      maxImageWidth: map['maxImageWidth'] as int? ?? 480,
    );
  }

  FaceDetectionConfig copyWith({
    int? frameSkipCount,
    double? blinkThreshold,
    bool? captureOnBlink,
    bool? cropToFace,
    double? imageQuality,
    int? maxImageWidth,
  }) {
    return FaceDetectionConfig(
      frameSkipCount: frameSkipCount ?? this.frameSkipCount,
      blinkThreshold: blinkThreshold ?? this.blinkThreshold,
      captureOnBlink: captureOnBlink ?? this.captureOnBlink,
      cropToFace: cropToFace ?? this.cropToFace,
      imageQuality: imageQuality ?? this.imageQuality,
      maxImageWidth: maxImageWidth ?? this.maxImageWidth,
    );
  }
}
