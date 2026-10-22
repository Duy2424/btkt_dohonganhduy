// Đăng nhập bằng khuôn mặt: chớp mắt (người thật) → chụp → so khớp cosine với mẫu ≥ FACE_THRESHOLD
// → gọi /api/auth/face-login { deviceId, faceToken } → vào app. Sai 3 lần liên tiếp → bắt buộc mật khẩu + OTP.
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/env.dart';
import '../../../../core/storage/local_prefs.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/session_controller.dart';
import '../../data/face_recognizer.dart';
import '../../data/face_storage.dart';
import '../../data/liveness_checker.dart';
import '../widgets/face_camera_view.dart';

class FaceLoginScreen extends ConsumerStatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  ConsumerState<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends ConsumerState<FaceLoginScreen> {
  CameraController? _camera;
  FaceRecognizer? _recognizer;
  final _liveness = LivenessChecker();
  Timer? _timeout;
  String _status = 'Đang mở camera...';
  String? _fatal;
  bool _busy = false;
  bool _scanning = false;
  Color? _ring;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _recognizer = await FaceRecognizer.create();
      _camera = await openFrontCamera();
      if (mounted) _startScan();
    } catch (e) {
      _fatal = e.toString();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    if (_camera?.value.isStreamingImages ?? false) _camera?.stopImageStream();
    _camera?.dispose();
    _recognizer?.dispose();
    _liveness.dispose();
    super.dispose();
  }

  void _startScan() {
    _liveness.stage = BlinkStage.waitingOpen;
    setState(() {
      _status = 'Nhìn vào camera và CHỚP MẮT một lần';
      _scanning = true;
      _ring = null;
    });
    _timeout = Timer(const Duration(seconds: 8), () => _fail('Không phát hiện chớp mắt trong 8 giây'));
    _camera!.startImageStream((image) async {
      if (await _liveness.process(image, _camera!.description) && _scanning) {
        _scanning = false;
        _timeout?.cancel();
        await _camera!.stopImageStream();
        _verify();
      }
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _status = 'Đang so khớp khuôn mặt...';
    });
    try {
      final template = await FaceStorage.load();
      final shot = await _camera!.takePicture();
      final embedding = await _recognizer!.embeddingFromFile(shot.path);
      final score = FaceRecognizer.cosine(embedding, template!.embedding);
      debugPrint('Độ giống khuôn mặt: ${score.toStringAsFixed(3)} (ngưỡng ${Env.faceThreshold})');
      if (score < Env.faceThreshold) {
        await _fail('Khuôn mặt không khớp (độ giống ${(score * 100).round()}%)');
        return;
      }

      final result = await ref.read(authApiProvider).faceLogin(LocalPrefs.instance.deviceId, (await FaceStorage.faceToken())!);
      await LocalPrefs.instance.setFaceFailCount(0);
      setState(() => _ring = AppColors.success);
      await ref.read(sessionProvider.notifier).completeLogin(result);
    } on FaceException catch (e) {
      _fail(e.message);
    } catch (e) {
      if (mounted) showError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fail(String reason) async {
    _timeout?.cancel();
    _scanning = false;
    if (_camera?.value.isStreamingImages ?? false) await _camera!.stopImageStream();
    final fails = LocalPrefs.instance.faceFailCount + 1;
    await LocalPrefs.instance.setFaceFailCount(fails);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ring = AppColors.danger;
      _status = '$reason. Sai $fails/3 lần.';
    });
    if (fails >= 3) {
      showError(context, 'Sai khuôn mặt 3 lần liên tiếp — hãy đăng nhập bằng mật khẩu + OTP');
      context.pop();
    }
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
            AppSpacing.gapLg,
            Center(child: FaceCameraView(controller: _camera, color: _ring ?? Theme.of(context).colorScheme.primary)),
            AppSpacing.gapLg,
            Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            AppSpacing.gapLg,
            if (!_scanning && !_busy && _camera != null)
              AppButton(label: 'Thử lại', icon: Icons.refresh, onPressed: _startScan),
            if (_busy) const Center(child: CircularProgressIndicator()),
          ],
          AppSpacing.gapMd,
          TextButton(onPressed: () => context.pop(), child: const Text('Dùng mật khẩu + OTP')),
        ],
      ),
    );
  }
}
