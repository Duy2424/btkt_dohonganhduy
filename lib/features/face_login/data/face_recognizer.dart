// Nhận diện khuôn mặt chạy hoàn toàn trên máy:
// ảnh chụp → ML Kit tìm khuôn mặt (đúng 1 mặt, đủ lớn, nhìn thẳng) → cắt mặt → MobileFaceNet (.tflite) → embedding
// → chuẩn hoá L2 → so cosine với mẫu đã lưu. Shape input/output đọc từ interpreter lúc chạy (không hardcode 112/192).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceException implements Exception {
  FaceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FaceRecognizer {
  FaceRecognizer._(this._interpreter, this._detector);

  static const modelAsset = 'assets/models/mobilefacenet.tflite';

  final Interpreter _interpreter;
  final FaceDetector _detector;

  /// Tải model; thiếu file → báo "Thiếu model nhận diện" thay vì crash.
  static Future<FaceRecognizer> create() async {
    try {
      final interpreter = await Interpreter.fromAsset(modelAsset);
      final detector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
      return FaceRecognizer._(interpreter, detector);
    } catch (e) {
      debugPrint('Không tải được model khuôn mặt: $e');
      throw FaceException('Thiếu model nhận diện (assets/models/mobilefacenet.tflite). Xem README mục "Model khuôn mặt".');
    }
  }

  void dispose() {
    _interpreter.close();
    _detector.close();
  }

  /// Tính embedding từ một ảnh chụp (file JPEG từ camera).
  Future<List<double>> embeddingFromFile(String path) async {
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) throw FaceException('Không thấy khuôn mặt, hãy nhìn thẳng vào camera');
    if (faces.length > 1) throw FaceException('Chỉ được có 1 khuôn mặt trong khung hình');
    final face = faces.first;
    if ((face.headEulerAngleY ?? 0).abs() > 15 || (face.headEulerAngleZ ?? 0).abs() > 15) {
      throw FaceException('Hãy nhìn thẳng, giữ đầu không nghiêng');
    }

    final image = await _decode(path);
    if (face.boundingBox.width < image.width * 0.25) throw FaceException('Đưa mặt lại gần camera hơn');

    final shape = _interpreter.getInputTensor(0).shape; // vd [1, 112, 112, 3]
    final batch = shape[0], h = shape[1], w = shape[2];
    final input = _cropResize(image, face.boundingBox, w, h);
    final outShape = _interpreter.getOutputTensor(0).shape; // vd [1, 192]
    final dim = outShape.last;
    final output = List.generate(outShape[0], (_) => List<double>.filled(dim, 0));
    _interpreter.run(List.generate(batch, (_) => input), output);
    return l2Normalize(output.first);
  }

  static double cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    for (var i = 0; i < min(a.length, b.length); i++) {
      dot += a[i] * b[i];
    }
    return dot; // cả 2 vector đã chuẩn hoá L2 → tích vô hướng = cosine similarity
  }

  static List<double> l2Normalize(List<double> v) {
    final norm = sqrt(v.fold<double>(0, (s, x) => s + x * x));
    return norm == 0 ? v : v.map((x) => x / norm).toList();
  }

  static List<double> average(List<List<double>> list) {
    final sum = List<double>.filled(list.first.length, 0);
    for (final v in list) {
      for (var i = 0; i < sum.length; i++) {
        sum[i] += v[i];
      }
    }
    return l2Normalize(sum.map((x) => x / list.length).toList());
  }

  Future<_Rgba> _decode(String path) async {
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _Rgba(frame.image.width, frame.image.height, data!.buffer.asUint8List());
  }

  /// Cắt vùng mặt (nới rộng 10%), thu nhỏ về w×h, chuẩn hoá pixel về [-1, 1] → tensor [h][w][3].
  List<List<List<double>>> _cropResize(_Rgba img, ui.Rect box, int w, int h) {
    final pad = box.width * 0.1;
    final left = max(0.0, box.left - pad), top = max(0.0, box.top - pad);
    final right = min(img.width.toDouble(), box.right + pad), bottom = min(img.height.toDouble(), box.bottom + pad);
    final cw = right - left, ch = bottom - top;
    return List.generate(h, (y) {
      final sy = (top + (y + 0.5) * ch / h).floor().clamp(0, img.height - 1);
      return List.generate(w, (x) {
        final sx = (left + (x + 0.5) * cw / w).floor().clamp(0, img.width - 1);
        final i = (sy * img.width + sx) * 4;
        return [
          (img.bytes[i] - 127.5) / 128,
          (img.bytes[i + 1] - 127.5) / 128,
          (img.bytes[i + 2] - 127.5) / 128,
        ];
      });
    });
  }
}

class _Rgba {
  _Rgba(this.width, this.height, this.bytes);
  final int width;
  final int height;
  final Uint8List bytes;
}
