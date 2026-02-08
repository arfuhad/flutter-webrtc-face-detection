import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FaceDetectionSample extends StatefulWidget {
  static String tag = 'face_detection_sample';

  @override
  _FaceDetectionSampleState createState() => _FaceDetectionSampleState();
}

class _FaceDetectionSampleState extends State<FaceDetectionSample> {
  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _cameraOn = false;
  bool _faceDetectionEnabled = false;
  bool _captureOnBlink = false;
  double _blinkThreshold = 0.3;

  FaceDetectionResult? _lastResult;
  final List<BlinkEvent> _blinkLog = [];
  StreamSubscription<FaceDetectionResult>? _faceSub;
  StreamSubscription<BlinkEvent>? _blinkSub;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _localRenderer.initialize();
  }

  @override
  void deactivate() {
    super.deactivate();
    _cleanup();
    _localRenderer.dispose();
  }

  Future<void> _cleanup() async {
    await _faceSub?.cancel();
    await _blinkSub?.cancel();
    _faceSub = null;
    _blinkSub = null;

    if (_faceDetectionEnabled && _localStream != null) {
      try {
        final track = _localStream!.getVideoTracks().first;
        if (track is MediaStreamTrackNative) {
          await track.disableFaceDetection();
        }
      } catch (_) {}
    }

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localRenderer.srcObject = null;
  }

  Future<void> _startCamera() async {
    final mediaConstraints = <String, dynamic>{
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    try {
      final stream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
    } catch (e) {
      print('Error getting user media: $e');
      return;
    }

    if (!mounted) return;
    setState(() {
      _cameraOn = true;
    });
  }

  Future<void> _stopCamera() async {
    if (_faceDetectionEnabled) {
      await _toggleFaceDetection();
    }
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localRenderer.srcObject = null;
    _localStream = null;

    if (!mounted) return;
    setState(() {
      _cameraOn = false;
      _lastResult = null;
    });
  }

  Future<void> _toggleFaceDetection() async {
    if (_localStream == null) return;

    final track = _localStream!.getVideoTracks().first;
    if (track is! MediaStreamTrackNative) {
      print('Track is not MediaStreamTrackNative');
      return;
    }

    if (_faceDetectionEnabled) {
      await _faceSub?.cancel();
      await _blinkSub?.cancel();
      _faceSub = null;
      _blinkSub = null;
      await track.disableFaceDetection();
      setState(() {
        _faceDetectionEnabled = false;
        _lastResult = null;
      });
    } else {
      final config = FaceDetectionConfig(
        blinkThreshold: _blinkThreshold,
        captureOnBlink: _captureOnBlink,
      );
      await track.enableFaceDetection(config: config);

      _faceSub = track.onFaceDetected.listen((result) {
        if (mounted) {
          setState(() {
            _lastResult = result;
          });
        }
      });

      _blinkSub = track.onBlinkDetected.listen((event) {
        if (mounted) {
          setState(() {
            _blinkLog.insert(0, event);
            if (_blinkLog.length > 50) {
              _blinkLog.removeLast();
            }
          });
        }
      });

      setState(() {
        _faceDetectionEnabled = true;
      });
    }
  }

  Future<void> _restartFaceDetection() async {
    if (!_faceDetectionEnabled || _localStream == null) return;

    final track = _localStream!.getVideoTracks().first;
    if (track is! MediaStreamTrackNative) return;

    await _faceSub?.cancel();
    await _blinkSub?.cancel();
    await track.disableFaceDetection();

    final config = FaceDetectionConfig(
      blinkThreshold: _blinkThreshold,
      captureOnBlink: _captureOnBlink,
    );
    await track.enableFaceDetection(config: config);

    _faceSub = track.onFaceDetected.listen((result) {
      if (mounted) setState(() => _lastResult = result);
    });
    _blinkSub = track.onBlinkDetected.listen((event) {
      if (mounted) {
        setState(() {
          _blinkLog.insert(0, event);
          if (_blinkLog.length > 50) _blinkLog.removeLast();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Detection'),
      ),
      body: Column(
        children: [
          // Camera preview
          Container(
            height: 300,
            width: double.infinity,
            color: Colors.black,
            child: _cameraOn
                ? RTCVideoView(_localRenderer, mirror: true)
                : Center(
                    child: Text('Camera off',
                        style: TextStyle(color: Colors.white54))),
          ),
          // Controls
          _buildControls(),
          // Face info + blink log
          Expanded(
            child: _faceDetectionEnabled
                ? _buildResultsPanel()
                : Center(
                    child: Text('Enable face detection to see results',
                        style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cameraOn ? _stopCamera : _startCamera,
        tooltip: _cameraOn ? 'Stop Camera' : 'Start Camera',
        child: Icon(_cameraOn ? Icons.videocam_off : Icons.videocam),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cameraOn ? _toggleFaceDetection : null,
                  icon: Icon(
                      _faceDetectionEnabled ? Icons.stop : Icons.face_retouching_natural),
                  label: Text(
                      _faceDetectionEnabled ? 'Disable Detection' : 'Enable Detection'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _faceDetectionEnabled
                      ? () {
                          setState(() => _blinkLog.clear());
                        }
                      : null,
                  icon: Icon(Icons.clear_all),
                  label: Text('Clear Log'),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Text('Capture on Blink'),
              Switch(
                value: _captureOnBlink,
                onChanged: _cameraOn
                    ? (val) {
                        setState(() => _captureOnBlink = val);
                        if (_faceDetectionEnabled) _restartFaceDetection();
                      }
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Blink Threshold: ${_blinkThreshold.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12)),
                    Slider(
                      value: _blinkThreshold,
                      min: 0.1,
                      max: 0.9,
                      divisions: 16,
                      onChanged: _cameraOn
                          ? (val) => setState(() => _blinkThreshold = val)
                          : null,
                      onChangeEnd: _faceDetectionEnabled
                          ? (_) => _restartFaceDetection()
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPanel() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            tabs: [
              Tab(text: 'Faces (${_lastResult?.faceCount ?? 0})'),
              Tab(text: 'Blinks (${_blinkLog.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFaceInfo(),
                _buildBlinkLog(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceInfo() {
    final result = _lastResult;
    if (result == null || !result.hasFaces) {
      return Center(
          child:
              Text('No faces detected', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: result.faces.length,
      itemBuilder: (context, index) {
        final face = result.faces[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Face #${index + 1}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (face.trackingId != null)
                  Text('Tracking ID: ${face.trackingId}',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: 8),
                _infoRow('Bounds',
                    '(${face.bounds.left}, ${face.bounds.top}) ${face.bounds.width}x${face.bounds.height}'),
                if (face.smilingProbability != null)
                  _infoRow('Smiling',
                      '${(face.smilingProbability! * 100).toStringAsFixed(1)}%'),
                if (face.headPose != null) ...[
                  SizedBox(height: 4),
                  Text('Head Pose',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  _infoRow(
                      'Yaw', '${face.headPose!.yaw.toStringAsFixed(1)}°'),
                  _infoRow(
                      'Pitch', '${face.headPose!.pitch.toStringAsFixed(1)}°'),
                  _infoRow(
                      'Roll', '${face.headPose!.roll.toStringAsFixed(1)}°'),
                ],
                if (face.landmarks != null) ...[
                  SizedBox(height: 4),
                  Text('Eyes',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (face.landmarks!.leftEye != null)
                    _infoRow('Left Eye',
                        '${face.landmarks!.leftEye!.isOpen ? "Open" : "Closed"} (${((face.landmarks!.leftEye!.openProbability ?? 0) * 100).toStringAsFixed(0)}%)'),
                  if (face.landmarks!.rightEye != null)
                    _infoRow('Right Eye',
                        '${face.landmarks!.rightEye!.isOpen ? "Open" : "Closed"} (${((face.landmarks!.rightEye!.openProbability ?? 0) * 100).toStringAsFixed(0)}%)'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildBlinkLog() {
    if (_blinkLog.isEmpty) {
      return Center(
          child: Text('No blinks detected yet',
              style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: _blinkLog.length,
      itemBuilder: (context, index) {
        final event = _blinkLog[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.remove_red_eye, size: 18, color: Colors.blue),
                    SizedBox(width: 6),
                    Text('${event.eye.name.toUpperCase()} blink',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Spacer(),
                    Text(
                        'L:${event.leftBlinkCount} R:${event.rightBlinkCount}',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                if (event.capturedFrame != null) ...[
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      base64Decode(event.capturedFrame!),
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
