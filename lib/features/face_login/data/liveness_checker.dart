// Kiểm tra "người thật" bằng chớp mắt: xác suất mở mắt (ML Kit) đi từ > 0.7 → < 0.3 → > 0.7 trong 8 giây.
// Chống dùng ảnh chụp tĩnh để đăng nhập.
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum BlinkStage { waitingOpen, waitingClosed, waitingReopen, done }

class LivenessChecker {
  LivenessChecker()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast),
        );

  final FaceDetector _detector;
  BlinkStage stage = BlinkStage.waitingOpen;
  bool _busy = false;

  void dispose() => _detector.close();

  /// Xử lý 1 khung hình camera; trả về true khi đã phát hiện đủ 1 lần chớp mắt.
  Future<bool> process(CameraImage image, CameraDescription camera) async {
    if (_busy || stage == BlinkStage.done) return stage == BlinkStage.done;
    _busy = true;
    try {
      final input = _toInputImage(image, camera);
      if (input == null) return false;
      final faces = await _detector.processImage(input);
      if (faces.length != 1) return false;
      final l = faces.first.leftEyeOpenProbability, r = faces.first.rightEyeOpenProbability;
      if (l == null || r == null) return false;
      switch (stage) {
        case BlinkStage.waitingOpen:
          if (l > 0.7 && r > 0.7) stage = BlinkStage.waitingClosed;
        case BlinkStage.waitingClosed:
          if (l < 0.3 && r < 0.3) stage = BlinkStage.waitingReopen;
        case BlinkStage.waitingReopen:
          if (l > 0.7 && r > 0.7) stage = BlinkStage.done;
        case BlinkStage.done:
          break;
      }
      return stage == BlinkStage.done;
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    if (!Platform.isAndroid || image.planes.isEmpty) return null;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format != InputImageFormat.nv21) return null;
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }
}
