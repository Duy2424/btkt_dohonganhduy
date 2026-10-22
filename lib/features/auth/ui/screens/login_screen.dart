// Màn đăng nhập bước 1: tên đăng nhập + mật khẩu → server gửi OTP qua email → sang màn nhập OTP.
// Có nút "Đăng nhập bằng khuôn mặt" khi máy này đã bật tính năng.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/local_prefs.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../face_login/data/face_storage.dart';
import '../../data/auth_api.dart';
import '../../state/session_controller.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _faceName;

  @override
  void initState() {
    super.initState();
    FaceStorage.enrolledUserName().then((name) {
      if (mounted) setState(() => _faceName = name);
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final challenge = await ref.read(authApiProvider).login(
            _username.text.trim().toLowerCase(),
            _password.text,
            LocalPrefs.instance.deviceId,
            'Điện thoại Android',
          );
      if (!mounted) return;
      context.push('/otp', extra: OtpArgs(purpose: OtpPurpose.login, challenge: challenge));
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      if (err.code == 'ACCOUNT_PENDING') {
        _askVerify(err);
      } else {
        showError(context, err);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _askVerify(ApiException err) async {
    final email = err.details is Map ? (err.details as Map)['email'] as String? : null;
    final ok = await confirmDialog(
      context,
      title: 'Tài khoản chưa xác minh email',
      message: 'Hãy xác minh email trước khi đăng nhập. Gửi lại mã xác minh tới email của bạn?',
      confirmLabel: 'Gửi lại mã',
      danger: false,
    );
    if (!ok || email == null || !mounted) return;
    try {
      final challenge = await ref.read(authApiProvider).resendVerifyEmail(email);
      if (!mounted) return;
      context.push('/otp', extra: OtpArgs(purpose: OtpPurpose.verifyEmail, challenge: challenge, email: email));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final faceBlocked = LocalPrefs.instance.faceFailCount >= 3;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppLogo(),
                    AppSpacing.gapLg,
                    Text('Đăng nhập', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    AppSpacing.gapLg,
                    AppTextField(
                      controller: _username,
                      label: 'Tên đăng nhập',
                      icon: Icons.person_outline,
                      validator: Validators.username,
                      plainAscii: true,
                      autofillHints: const [AutofillHints.username],
                    ),
                    AppSpacing.gapMd,
                    AppTextField(
                      controller: _password,
                      label: 'Mật khẩu',
                      icon: Icons.lock_outline,
                      obscure: true,
                      validator: (v) => Validators.required(v, 'mật khẩu'),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      autofillHints: const [AutofillHints.password],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Quên mật khẩu?')),
                    ),
                    AppButton(label: 'Đăng nhập', icon: Icons.login, loading: _loading, onPressed: _submit),
                    if (_faceName != null) ...[
                      AppSpacing.gapMd,
                      AppButton(
                        label: faceBlocked ? 'Sai khuôn mặt 3 lần — dùng mật khẩu + OTP' : 'Đăng nhập bằng khuôn mặt',
                        icon: Icons.face_retouching_natural,
                        outlined: true,
                        onPressed: faceBlocked ? null : () => context.push('/face-login'),
                      ),
                    ],
                    AppSpacing.gapLg,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(onPressed: () => context.push('/register'), child: const Text('Đăng ký')),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => ref.read(sessionProvider.notifier).resetMode(),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Đây là máy của con? Đổi loại máy'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
