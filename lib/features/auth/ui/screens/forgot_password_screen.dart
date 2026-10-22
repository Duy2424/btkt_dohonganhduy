// Quên mật khẩu: bước 1 nhập email → server gửi OTP; bước 2 nhập OTP + mật khẩu mới → đặt lại → về đăng nhập.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/otp_input.dart';
import '../../data/auth_api.dart';
import '../../data/models/app_user.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otpKey = GlobalKey<OtpInputState>();
  OtpChallenge? _challenge;
  bool _loading = false;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final c = await ref.read(authApiProvider).forgotPassword(_email.text.trim().toLowerCase());
      if (mounted) setState(() => _challenge = c);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    final code = _otpKey.currentState?.code ?? '';
    if (Validators.otp(code) != null) return showError(context, 'Mã OTP gồm 6 chữ số');
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _passwordError = null;
    });
    try {
      await ref.read(authApiProvider).resetPassword(_challenge!.otpSessionId, code, _password.text);
      if (!mounted) return;
      showSuccess(context, 'Đặt lại mật khẩu thành công, hãy đăng nhập lại');
      context.go('/login');
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      if (err.fieldErrors['newPassword'] != null) {
        setState(() => _passwordError = err.fieldErrors['newPassword']);
      } else {
        showError(context, err);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _challenge != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _email,
                  label: 'Email đã đăng ký',
                  icon: Icons.email_outlined,
                  enabled: !sent,
                  keyboardType: TextInputType.emailAddress,
                  plainAscii: true,
                  validator: Validators.email,
                ),
                AppSpacing.gapLg,
                if (!sent)
                  AppButton(label: 'Gửi mã OTP', icon: Icons.send, loading: _loading, onPressed: _sendCode)
                else ...[
                  Text('Nhập mã đã gửi tới ${_challenge!.maskedEmail}', textAlign: TextAlign.center),
                  AppSpacing.gapMd,
                  OtpInput(key: _otpKey, onCompleted: (_) {}),
                  AppSpacing.gapLg,
                  AppTextField(
                    controller: _password,
                    label: 'Mật khẩu mới',
                    icon: Icons.lock_reset,
                    obscure: true,
                    validator: Validators.password,
                    serverError: _passwordError,
                  ),
                  AppSpacing.gapLg,
                  AppButton(label: 'Đặt lại mật khẩu', loading: _loading, onPressed: _reset),
                  AppSpacing.gapMd,
                  const InfoBanner(text: 'Không thấy mail? Kiểm tra mục Spam / Thư rác.', icon: Icons.tips_and_updates_outlined),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
