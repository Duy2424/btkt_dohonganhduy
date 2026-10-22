// Màn đăng ký tài khoản phụ huynh qua email: kiểm tra từng ô (cùng luật server), trùng email/username báo đúng ô,
// thành công → sang màn nhập OTP xác minh email.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/auth_api.dart';
import 'otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    for (final c in [_fullName, _username, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _email.text.trim().toLowerCase();
      final challenge = await ref.read(authApiProvider).register(
            fullName: _fullName.text.trim(),
            username: _username.text.trim().toLowerCase(),
            email: email,
            password: _password.text,
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      context.pushReplacement('/otp', extra: OtpArgs(purpose: OtpPurpose.verifyEmail, challenge: challenge, email: email));
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      if (err.fieldErrors.isNotEmpty) {
        setState(() => _serverErrors = err.fieldErrors);
      } else {
        showError(context, err);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tài khoản phụ huynh', style: Theme.of(context).textTheme.titleMedium),
                AppSpacing.gapLg,
                AppTextField(controller: _fullName, label: 'Họ và tên', icon: Icons.badge_outlined,
                    validator: Validators.fullName, serverError: _serverErrors['fullName']),
                AppSpacing.gapMd,
                AppTextField(controller: _username, label: 'Tên đăng nhập', icon: Icons.person_outline,
                    hint: 'chữ thường, số, dấu _', plainAscii: true, validator: Validators.username, serverError: _serverErrors['username']),
                AppSpacing.gapMd,
                AppTextField(controller: _email, label: 'Email', icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress, plainAscii: true, validator: Validators.email, serverError: _serverErrors['email']),
                AppSpacing.gapMd,
                AppTextField(controller: _phone, label: 'Số điện thoại (tuỳ chọn)', icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone, validator: Validators.phone, serverError: _serverErrors['phone']),
                AppSpacing.gapMd,
                AppTextField(controller: _password, label: 'Mật khẩu', icon: Icons.lock_outline, obscure: true,
                    hint: '≥ 8 ký tự, có chữ và số', validator: Validators.password, serverError: _serverErrors['password']),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _confirm,
                  label: 'Nhập lại mật khẩu',
                  icon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
                ),
                AppSpacing.gapLg,
                AppButton(label: 'Đăng ký', icon: Icons.person_add_alt_1, loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
