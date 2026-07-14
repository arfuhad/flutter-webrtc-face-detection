#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc_face_detection'
  s.version          = '0.1.0'
  s.summary          = 'Flutter WebRTC + on-device face-detection plugin for iOS.'
  s.description      = <<-DESC
WebRTC plugin with an on-device ML face-detection / blink pipeline. Hard fork of flutter_webrtc.
                       DESC
  s.homepage         = 'https://github.com/arfuhad/flutter-webrtc-face-detection'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'WebRTC-SDK', '144.7559.09'
  s.ios.deployment_target = '13.0'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'USER_HEADER_SEARCH_PATHS' => 'Classes/**/*.h'
  }
  s.libraries = 'c++'
end
