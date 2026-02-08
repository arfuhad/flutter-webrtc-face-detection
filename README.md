# Flutter WebRTC with Face Detection

A fork of [flutter-webrtc](https://github.com/flutter-webrtc/flutter-webrtc) that adds integrated ML Kit-based face detection, eye tracking, and blink detection for Android and iOS.

> **Based on [flutter-webrtc](https://github.com/flutter-webrtc/flutter-webrtc)** by [CloudWebRTC](https://github.com/cloudwebrtc) and contributors. All original WebRTC functionality is preserved — this fork extends it with face detection capabilities.

## Functionality

| Feature | Android | iOS | [Web](https://flutter.dev/web) | macOS | Windows | Linux | [Embedded](https://github.com/sony/flutter-elinux) | [Fuchsia](https://fuchsia.dev/) |
| :-------------: | :-------------:| :-----: | :-----: | :-----: | :-----: | :-----: | :-----: | :-----: |
| Audio/Video | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Data Channel | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Screen Capture | :heavy_check_mark: | [:heavy_check_mark:(*)](https://github.com/flutter-webrtc/flutter-webrtc/wiki/iOS-Screen-Sharing) | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Unified-Plan | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Simulcast | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| MediaRecorder | :warning: | :warning: | :heavy_check_mark: | | | | | |
| End to End Encryption | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Insertable Streams | | | | | | | | |
| Face Detection (ML Kit) | :heavy_check_mark: | :heavy_check_mark: | | | | | | |

Additional platform/OS support from the other community

- flutter-tizen: <https://github.com/flutter-tizen/plugins/tree/master/packages/flutter_webrtc>
- flutter-elinux(WIP): <https://github.com/sony/flutter-elinux-plugins/issues/7>

Add `flutter_webrtc` as a [dependency in your pubspec.yaml file](https://flutter.io/using-packages/).

### iOS

Add the following entry to your _Info.plist_ file, located in `<project root>/ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) Camera Usage!</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) Microphone Usage!</string>
```

This entry allows your app to access camera and microphone.

### Note for iOS

The WebRTC.xframework compiled after the m104 release no longer supports iOS arm devices, so need to add the `config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'` to your ios/Podfile in your project

ios/Podfile

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
     target.build_configurations.each do |config|
      # Workaround for https://github.com/flutter/flutter/issues/64502
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES' # <= this line
     end
  end
end
```

### Android

Ensure the following permission is present in your Android Manifest file, located in `<project root>/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

If you need to use a Bluetooth device, please add:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
```

The Flutter project template adds it, so it may already be there.

Also you will need to set your build settings to Java 8, because official WebRTC jar now uses static methods in `EglBase` interface. Just add this to your app level `build.gradle`:

```groovy
android {
    //...
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

If necessary, in the same `build.gradle` you will need to increase `minSdkVersion` of `defaultConfig` up to `23` (currently default Flutter generator set it to `16`).

### Important reminder

When you compile the release apk, you need to add the following operations,
[Setup Proguard Rules](https://github.com/flutter-webrtc/flutter-webrtc/blob/main/android/proguard-rules.pro)

## Face Detection

This fork adds ML Kit-based face detection integrated into the WebRTC video pipeline. Available on **Android** and **iOS** only.

### Features

- Face detection with bounding boxes and tracking IDs
- Facial landmarks (eyes, nose, mouth positions)
- Head pose estimation (yaw, pitch, roll)
- Eye tracking with open/closed state and probability
- Blink detection with per-eye counting
- Optional frame capture on blink (base64 JPEG)
- Non-blocking — runs on a dedicated thread, does not block the video pipeline
- Configurable frame skipping for performance tuning

### Requirements

- **iOS**: 15.5+ (ML Kit requirement)
- **Android**: API 24+ (minSdk)

### Usage

```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

// Get video track
final stream = await navigator.mediaDevices.getUserMedia({'video': true});
final videoTrack = stream.getVideoTracks().first as MediaStreamTrackNative;

// Enable face detection
await videoTrack.enableFaceDetection(
  config: FaceDetectionConfig(
    blinkThreshold: 0.3,
    captureOnBlink: false,
  ),
);

// Listen to face detection results
videoTrack.onFaceDetected.listen((result) {
  for (final face in result.faces) {
    print('Face at ${face.bounds}, tracking: ${face.trackingId}');
    if (face.landmarks?.leftEye != null) {
      print('Left eye open: ${face.landmarks!.leftEye!.isOpen}');
    }
  }
});

// Listen to blink events
videoTrack.onBlinkDetected.listen((event) {
  print('Blink: ${event.eye.name}, count: ${event.blinkCount}');
});

// Disable when done
await videoTrack.disableFaceDetection();
```

### Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `frameSkipCount` | 3 | Process every Nth frame (~10 detections/sec at 30fps) |
| `blinkThreshold` | 0.3 | Eye open probability threshold (0.0-1.0) |
| `captureOnBlink` | false | Capture a JPEG frame on blink |
| `cropToFace` | true | Crop captured image to face bounds |
| `imageQuality` | 0.7 | JPEG quality (0.0-1.0) |
| `maxImageWidth` | 480 | Max captured image width in pixels |

### Example App

The example app includes a **Face Detection** sample that demonstrates all features with a live camera preview, real-time face info display, blink event log, and configurable controls.

```bash
cd example && flutter run
```

