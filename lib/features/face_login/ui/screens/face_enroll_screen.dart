// Bật đăng nhập khuôn mặt (Cài đặt → Đăng nhập bằng khuôn mặt): chụp 5 khung hình → embedding trung bình
// → nhập lại mật khẩu → server ghi nhận máy tin cậy + cấp faceToken → lưu mẫu trong secure storage của máy.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/storage/local_prefs.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/session_controller.dart';
import '../../data/face_recognizer.dart';
import '../../data/face_storage.dart';
import '../widgets/face_camera_view.dart';

class FaceEnrollScreen extends ConsumerStatefulWidget {
  const FaceEnrollScreen({super.key});

  @override
  ConsumerState<FaceEnrollScreen> createState() => _FaceEnrollScreenState();
}

class _FaceEnrollScreenState extends ConsumerState<FaceEnrollScreen> {
  CameraController? _camera;
  FaceRecognizer? _recognizer;
  String _status = 'Đang mở camera...';
  String? _fatal;
  bool _busy = false;
  bool _enabled = false;
  int _captured = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _enabled = await FaceStorage.enrolledUserName() != null;
    try {
      _recognizer = await FaceRecognizer.create();
      _camera = await openFrontCamera();
      _status = 'Nhìn thẳng vào camera, đủ sáng, rồi bấm "Bắt đầu"';
    } catch (e) {
      _fatal = e.toString();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _camera?.dispose();
    _recognizer?.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    setState(() => _busy = true);
    final embeddings = <List<double>>[];
    var attempts = 0;
    try {
      while (embeddings.length < 5 && attempts < 15) {
        attempts++;
        final shot = await _camera!.takePicture();
        try {
          embeddings.add(await _recognizer!.embeddingFromFile(shot.path));
          setState(() {
            _captured = embeddings.length;
            _status = 'Đã chụp ${embeddings.length}/5 — giữ yên...';
          });
        } on FaceException catch (e) {
          setState(() => _status = e.message);
        }
      }
      if (embeddings.length < 5) throw FaceException('Chưa chụp đủ 5 ảnh rõ mặt, hãy thử lại nơi đủ sáng');

      if (!mounted) return;
      final password = await _askPassword();
      if (password == null) return;
      final user = ref.read(sessionProvider).user!;
      final faceToken = await ref.read(authApiProvider).setFaceLogin(
            enabled: true,
            deviceId: LocalPrefs.instance.deviceId,
            deviceName: 'Điện thoại Android',
            password: password,
          );
      await FaceStorage.save(
        FaceTemplate(userId: user.id, userName: user.fullName, embedding: FaceRecognizer.average(embeddings)),
        faceToken!,
      );
      await LocalPrefs.instance.setFaceFailCount(0);
      if (!mounted) return;
      showSuccess(context, 'Đã bật đăng nhập bằng khuôn mặt trên máy này');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e is FaceException ? e.message : e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _captured = 0;
        });
      }
    }
  }

  Future<void> _disable() async {
    try {
      await ref.read(authApiProvider).setFaceLogin(enabled: false, deviceId: LocalPrefs.instance.deviceId);
      await FaceStorage.clear();
      if (!mounted) return;
      showSuccess(context, 'Đã tắt đăng nhập khuôn mặt');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<String?> _askPassword() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận mật khẩu'),
        content: TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Xác nhận')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập bằng khuôn mặt')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_fatal != null)
            EmptyView(message: _fatal!, icon: Icons.face_retouching_off)
          else ...[
            Center(child: FaceCameraView(controller: _camera, color: _captured > 0 ? AppColors.success : Theme.of(context).colorScheme.primary)),
            AppSpacing.gapMd,
            Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            AppSpacing.gapLg,
            AppButton(
              label: _enabled ? 'Đăng ký lại khuôn mặt' : 'Bắt đầu',
              icon: Icons.camera_alt_outlined,
              loading: _busy,
              onPressed: _camera == null ? null : _enroll,
            ),
          ],
          if (_enabled) ...[
            AppSpacing.gapMd,
            AppButton(label: 'Tắt đăng nhập khuôn mặt', outlined: true, onPressed: _disable),
          ],
        ],
      ),
    );
  }
}
