/// Represents the head pose (rotation) of a detected face.
class HeadPose {
  /// Rotation around the vertical axis (looking left/right) in degrees.
  /// Positive values indicate the face is turned towards the right side of the image.
  final double yaw;

  /// Rotation around the horizontal axis (looking up/down) in degrees.
  /// Positive values indicate the face is tilted upward.
  final double pitch;

  /// Rotation around the axis pointing out of the screen (head tilt) in degrees.
  /// Positive values indicate the face is tilted towards the left shoulder.
  final double roll;

  const HeadPose({
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  factory HeadPose.fromMap(Map<String, dynamic> map) {
    return HeadPose(
      yaw: (map['yaw'] as num?)?.toDouble() ?? 0.0,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 0.0,
      roll: (map['roll'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'yaw': yaw,
      'pitch': pitch,
      'roll': roll,
    };
  }

  @override
  String toString() => 'HeadPose(yaw: $yaw, pitch: $pitch, roll: $roll)';
}
