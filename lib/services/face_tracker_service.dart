import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

enum FaceStartResult { started, permissionDenied, permissionPermanentlyDenied, noCamera, failed }

/// Supplementary facial-movement summary for one speaking attempt.
///
/// This is NOT a pronunciation score. Face detection can tell that the mouth
/// and jaw moved while the learner spoke; it cannot tell whether the sounds
/// were right. The app shows it as an extra hint only and it never changes
/// the points.
class FaceActivitySummary {
  const FaceActivitySummary({
    required this.samples,
    required this.facePresentRatio,
    required this.mouthRange,
    required this.jawRange,
    required this.movementDetected,
  });

  final int samples;

  /// Share of frames in which a face was visible.
  final double facePresentRatio;

  /// Max minus min lip gap, as a fraction of face height.
  final double mouthRange;

  /// Max minus min nose-to-chin distance, as a fraction of face height.
  final double jawRange;

  /// Face mostly visible and the lips moved noticeably during the speech window.
  final bool movementDetected;
}

class _Sample {
  const _Sample(this.faceFound, this.mouth, this.jaw);
  final bool faceFound;
  final double mouth;
  final double jaw;
}

/// Camera + ML Kit face detection with contours and landmarks.
///
/// - Asks for camera permission before opening the camera.
/// - Uses the front camera, no audio, and never records or saves video.
/// - Call [beginWindow] when the learner starts speaking and [endWindow] when
///   they stop, to relate lip/jaw movement to the speech timing.
class FaceTrackerService extends ChangeNotifier {
  CameraController? _camera;
  CameraDescription? _description;
  FaceDetector? _detector;
  bool _processing = false;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

  bool running = false;
  bool faceDetected = false;

  /// Current lip gap relative to face height (about 0.0 closed, 0.1+ wide open).
  double mouthOpenness = 0;
  double jawOpenness = 0;

  bool _windowOpen = false;
  final List<_Sample> _samples = [];

  CameraController? get camera => _camera;

  Future<FaceStartResult> start() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) return FaceStartResult.permissionPermanentlyDenied;
    if (!status.isGranted) return FaceStartResult.permissionDenied;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return FaceStartResult.noCamera;
      _description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        _description!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();

      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      _camera = controller;
      await controller.startImageStream(_onFrame);
      running = true;
      notifyListeners();
      return FaceStartResult.started;
    } on CameraException catch (e) {
      await stop();
      return e.code.toLowerCase().contains('denied')
          ? FaceStartResult.permissionDenied
          : FaceStartResult.failed;
    } catch (_) {
      await stop();
      return FaceStartResult.failed;
    }
  }

  Future<void> stop() async {
    running = false;
    faceDetected = false;
    _windowOpen = false;
    final cam = _camera;
    _camera = null;
    try {
      if (cam != null && cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (_) {}
    await cam?.dispose();
    await _detector?.close();
    _detector = null;
    notifyListeners();
  }

  void beginWindow() {
    _samples.clear();
    _windowOpen = true;
  }

  FaceActivitySummary endWindow() {
    _windowOpen = false;
    final withFace = _samples.where((s) => s.faceFound).toList();
    double range(Iterable<double> v) =>
        v.isEmpty ? 0 : v.reduce(math.max) - v.reduce(math.min);

    final present = _samples.isEmpty ? 0.0 : withFace.length / _samples.length;
    final mouthRange = range(withFace.map((s) => s.mouth));
    final jawRange = range(withFace.map((s) => s.jaw));
    return FaceActivitySummary(
      samples: _samples.length,
      facePresentRatio: present,
      mouthRange: mouthRange,
      jawRange: jawRange,
      // 2% of face height is a visible lip movement; below that it is noise.
      movementDetected: present >= 0.5 && mouthRange >= 0.02,
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    final detector = _detector;
    final description = _description;
    if (detector == null || description == null || _processing) return;
    final now = DateTime.now();
    if (now.difference(_lastProcessed) < const Duration(milliseconds: 120)) return;
    _lastProcessed = now;
    _processing = true;

    try {
      final input = _toInputImage(image, description);
      if (input == null) return;
      final faces = await detector.processImage(input);

      if (faces.isEmpty) {
        faceDetected = false;
        if (_windowOpen) _samples.add(const _Sample(false, 0, 0));
      } else {
        final face = faces.reduce(
          (a, b) => a.boundingBox.height >= b.boundingBox.height ? a : b,
        );
        faceDetected = true;
        _measure(face);
        if (_windowOpen) _samples.add(_Sample(true, mouthOpenness, jawOpenness));
      }
      notifyListeners();
    } catch (_) {
      // A dropped frame is harmless.
    } finally {
      _processing = false;
    }
  }

  void _measure(Face face) {
    final h = face.boundingBox.height;
    if (h <= 0) return;

    double avgY(List<math.Point<int>> pts) =>
        pts.map((p) => p.y).reduce((a, b) => a + b) / pts.length;

    final upper = face.contours[FaceContourType.upperLipBottom]?.points;
    final lower = face.contours[FaceContourType.lowerLipTop]?.points;
    if (upper != null && lower != null && upper.isNotEmpty && lower.isNotEmpty) {
      mouthOpenness = ((avgY(lower) - avgY(upper)) / h).clamp(0.0, 1.0);
    }

    final outline = face.contours[FaceContourType.face]?.points;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    if (outline != null && outline.isNotEmpty && nose != null) {
      final chinY = outline.map((p) => p.y).reduce(math.max);
      jawOpenness = ((chinY - nose.y) / h).clamp(0.0, 2.0);
    }
  }

  /// Converts a camera frame to an ML Kit InputImage.
  /// The app is locked to portrait, so the sensor orientation is the rotation.
  InputImage? _toInputImage(CameraImage image, CameraDescription cam) {
    final rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
