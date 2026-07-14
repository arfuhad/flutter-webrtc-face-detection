import 'package:flutter_webrtc_face_detection/flutter_webrtc.dart';

extension VideoRendererExtension on RTCVideoRenderer {
  RTCVideoValue get videoValue => value;
}

abstract class AudioControl {
  Future<void> setVolume(double volume);
}
