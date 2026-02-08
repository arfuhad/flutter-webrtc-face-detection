/// Represents the state of an eye.
class EyeState {
  /// X coordinate of the eye position.
  final double x;

  /// Y coordinate of the eye position.
  final double y;

  /// Probability that the eye is open (0.0-1.0).
  /// Only available when classification mode is enabled.
  final double? openProbability;

  /// Whether the eye is considered open based on the blink threshold.
  final bool isOpen;

  const EyeState({
    required this.x,
    required this.y,
    this.openProbability,
    this.isOpen = true,
  });

  factory EyeState.fromMap(Map<String, dynamic> map) {
    return EyeState(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      openProbability: (map['openProbability'] as num?)?.toDouble(),
      isOpen: map['isOpen'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      if (openProbability != null) 'openProbability': openProbability,
      'isOpen': isOpen,
    };
  }

  @override
  String toString() =>
      'EyeState(x: $x, y: $y, openProbability: $openProbability, isOpen: $isOpen)';
}

/// Represents a point landmark (e.g., nose).
class PointLandmark {
  /// X coordinate of the landmark.
  final double x;

  /// Y coordinate of the landmark.
  final double y;

  const PointLandmark({
    required this.x,
    required this.y,
  });

  factory PointLandmark.fromMap(Map<String, dynamic> map) {
    return PointLandmark(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
    };
  }

  @override
  String toString() => 'PointLandmark(x: $x, y: $y)';
}

/// Represents the mouth landmark.
class MouthLandmark {
  /// X coordinate of the left corner of the mouth.
  final double leftX;

  /// Y coordinate of the left corner of the mouth.
  final double leftY;

  /// X coordinate of the right corner of the mouth.
  final double rightX;

  /// Y coordinate of the right corner of the mouth.
  final double rightY;

  /// X coordinate of the bottom of the mouth (may be null).
  final double? bottomX;

  /// Y coordinate of the bottom of the mouth (may be null).
  final double? bottomY;

  /// Probability that the face is smiling (0.0-1.0).
  final double? smilingProbability;

  const MouthLandmark({
    required this.leftX,
    required this.leftY,
    required this.rightX,
    required this.rightY,
    this.bottomX,
    this.bottomY,
    this.smilingProbability,
  });

  factory MouthLandmark.fromMap(Map<String, dynamic> map) {
    return MouthLandmark(
      leftX: (map['leftX'] as num?)?.toDouble() ?? 0.0,
      leftY: (map['leftY'] as num?)?.toDouble() ?? 0.0,
      rightX: (map['rightX'] as num?)?.toDouble() ?? 0.0,
      rightY: (map['rightY'] as num?)?.toDouble() ?? 0.0,
      bottomX: (map['bottomX'] as num?)?.toDouble(),
      bottomY: (map['bottomY'] as num?)?.toDouble(),
      smilingProbability: (map['smilingProbability'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leftX': leftX,
      'leftY': leftY,
      'rightX': rightX,
      'rightY': rightY,
      if (bottomX != null) 'bottomX': bottomX,
      if (bottomY != null) 'bottomY': bottomY,
      if (smilingProbability != null) 'smilingProbability': smilingProbability,
    };
  }

  @override
  String toString() =>
      'MouthLandmark(left: ($leftX, $leftY), right: ($rightX, $rightY), smiling: $smilingProbability)';
}

/// Represents the facial landmarks detected on a face.
class FaceLandmarks {
  /// Left eye state and position.
  final EyeState? leftEye;

  /// Right eye state and position.
  final EyeState? rightEye;

  /// Nose position.
  final PointLandmark? nose;

  /// Mouth landmark.
  final MouthLandmark? mouth;

  const FaceLandmarks({
    this.leftEye,
    this.rightEye,
    this.nose,
    this.mouth,
  });

  factory FaceLandmarks.fromMap(Map<String, dynamic> map) {
    return FaceLandmarks(
      leftEye: map['leftEye'] != null
          ? EyeState.fromMap(Map<String, dynamic>.from(map['leftEye'] as Map))
          : null,
      rightEye: map['rightEye'] != null
          ? EyeState.fromMap(Map<String, dynamic>.from(map['rightEye'] as Map))
          : null,
      nose: map['nose'] != null
          ? PointLandmark.fromMap(Map<String, dynamic>.from(map['nose'] as Map))
          : null,
      mouth: map['mouth'] != null
          ? MouthLandmark.fromMap(Map<String, dynamic>.from(map['mouth'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (leftEye != null) 'leftEye': leftEye!.toMap(),
      if (rightEye != null) 'rightEye': rightEye!.toMap(),
      if (nose != null) 'nose': nose!.toMap(),
      if (mouth != null) 'mouth': mouth!.toMap(),
    };
  }

  @override
  String toString() =>
      'FaceLandmarks(leftEye: $leftEye, rightEye: $rightEye, nose: $nose, mouth: $mouth)';
}
