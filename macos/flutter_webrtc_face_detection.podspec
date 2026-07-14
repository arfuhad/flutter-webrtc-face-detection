#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc_face_detection'
  s.version          = '0.1.0'
  s.summary          = 'Flutter WebRTC + on-device face-detection plugin for macOS.'
  s.description      = <<-DESC
WebRTC plugin with an on-device ML face-detection / blink pipeline. Hard fork of flutter_webrtc.
                       DESC
  s.homepage         = 'https://github.com/arfuhad/flutter-webrtc-face-detection'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = ['Classes/**/*']

  s.dependency 'FlutterMacOS'
  s.weak_frameworks = 'ScreenCaptureKit'
  s.dependency 'WebRTC-SDK', '144.7559.09'
  s.osx.deployment_target = '10.15'
end
