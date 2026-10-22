// Khung camera trước hình tròn dùng chung cho màn đăng ký & đăng nhập khuôn mặt.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceCameraView extends StatelessWidget {
  const FaceCameraView({super.key, required this.controller, required this.color});
  final CameraController? controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ready = controller != null && controller!.value.isInitialized;
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 5)),
      child: ClipOval(
        child: ready
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.previewSize!.height,
                  height: controller!.value.previewSize!.width,
                  child: CameraPreview(controller!),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Mở camera trước (định dạng NV21 để ML Kit đọc trực tiếp khung hình).
Future<CameraController> openFrontCamera() async {
  final cameras = await availableCameras();
  final front = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );
  final controller = CameraController(
    front,
    ResolutionPreset.medium,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.nv21,
  );
  await controller.initialize();
  return controller;
}
