import 'face_landmarks.dart';
import 'head_pose.dart';

/// Represents a bounding box for a detected face.
class BoundingBox {
  /// Left coordinate of the bounding box.
  final int left;

  /// Top coordinate of the bounding box.
  final int top;

  /// Width of the bounding box.
  final int width;

  /// Height of the bounding box.
  final int height;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Right coordinate of the bounding box.
  int get right => left + width;

  /// Bottom coordinate of the bounding box.
  int get bottom => top + height;

  factory BoundingBox.fromMap(Map<String, dynamic> map) {
    return BoundingBox(
      left: map['left'] as int? ?? 0,
      top: map['top'] as int? ?? 0,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() =>
      'BoundingBox(left: $left, top: $top, width: $width, height: $height)';
}

/// Represents a detected face with its properties.
class Face {
  /// Bounding box of the face in the image.
  final BoundingBox bounds;

  /// Face tracking ID. Consistent across frames for the same face.
  final int? trackingId;

  /// Head pose (rotation).
  final HeadPose? headPose;

  /// Facial landmarks (eyes, nose, mouth).
  final FaceLandmarks? landmarks;

  /// Probability that the face is smiling (0.0-1.0).
  final double? smilingProbability;

  const Face({
    required this.bounds,
    this.trackingId,
    this.headPose,
    this.landmarks,
    this.smilingProbability,
  });

  factory Face.fromMap(Map<String, dynamic> map) {
    return Face(
      bounds: BoundingBox.fromMap(
        Map<String, dynamic>.from(map['bounds'] as Map),
      ),
      trackingId: map['trackingId'] as int?,
      headPose: map['headPose'] != null
          ? HeadPose.fromMap(Map<String, dynamic>.from(map['headPose'] as Map))
          : null,
      landmarks: map['landmarks'] != null
          ? FaceLandmarks.fromMap(
              Map<String, dynamic>.from(map['landmarks'] as Map))
          : null,
      smilingProbability: (map['smilingProbability'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bounds': bounds.toMap(),
      if (trackingId != null) 'trackingId': trackingId,
      if (headPose != null) 'headPose': headPose!.toMap(),
      if (landmarks != null) 'landmarks': landmarks!.toMap(),
      if (smilingProbability != null) 'smilingProbability': smilingProbability,
    };
  }

  @override
  String toString() =>
      'Face(bounds: $bounds, trackingId: $trackingId, smiling: $smilingProbability)';
}

/// Represents the result of face detection on a single frame.
class FaceDetectionResult {
  /// List of detected faces.
  final List<Face> faces;

  /// Timestamp of the frame in nanoseconds.
  final int? timestamp;

  /// Width of the frame in pixels.
  final int? frameWidth;

  /// Height of the frame in pixels.
  final int? frameHeight;

  const FaceDetectionResult({
    required this.faces,
    this.timestamp,
    this.frameWidth,
    this.frameHeight,
  });

  /// Whether any faces were detected.
  bool get hasFaces => faces.isNotEmpty;

  /// Number of detected faces.
  int get faceCount => faces.length;

  factory FaceDetectionResult.fromMap(Map<String, dynamic> map) {
    final facesList = map['faces'] as List<dynamic>?;
    return FaceDetectionResult(
      faces: facesList
              ?.map((f) => Face.fromMap(Map<String, dynamic>.from(f as Map)))
              .toList() ??
          [],
      timestamp: map['timestamp'] as int?,
      frameWidth: map['frameWidth'] as int?,
      frameHeight: map['frameHeight'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'faces': faces.map((f) => f.toMap()).toList(),
      if (timestamp != null) 'timestamp': timestamp,
      if (frameWidth != null) 'frameWidth': frameWidth,
      if (frameHeight != null) 'frameHeight': frameHeight,
    };
  }

  @override
  String toString() =>
      'FaceDetectionResult(faceCount: $faceCount, frameSize: ${frameWidth}x$frameHeight)';
}
