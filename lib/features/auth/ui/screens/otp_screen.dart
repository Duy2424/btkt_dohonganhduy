// Màn nhập OTP 6 số dùng chung cho: xác minh email sau đăng ký và bước 2 của đăng nhập.
// Có đếm ngược "Gửi lại mã" 60 giây và nhắc kiểm tra thư mục Spam.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/otp_input.dart';
import '../../data/auth_api.dart';
import '../../data/models/app_user.dart';
import '../../state/session_controller.dart';

enum OtpPurpose { verifyEmail, login }

class OtpArgs {
  const OtpArgs({required this.purpose, required this.challenge, this.email});
  final OtpPurpose purpose;
  final OtpChallenge challenge;
  final String? email;
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});
  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpKey = GlobalKey<OtpInputState>();
  late OtpChallenge _challenge = widget.args.challenge;
  Timer? _timer;
  int _seconds = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(_challenge.resendAfter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _seconds = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) t.cancel();
      if (mounted) setState(() => _seconds -= 1);
    });
  }

  Future<void> _verify(String code) async {
    if (code.length != 6 || _loading) return;
    setState(() => _loading = true);
    final api = ref.read(authApiProvider);
    try {
      if (widget.args.purpose == OtpPurpose.verifyEmail) {
        await api.verifyEmail(_challenge.otpSessionId, code);
        if (!mounted) return;
        showSuccess(context, 'Xác minh email thành công! Hãy đăng nhập.');
        context.go('/login');
      } else {
        final result = await api.verifyLoginOtp(_challenge.otpSessionId, code);
        await ref.read(sessionProvider.notifier).completeLogin(result);
        // Router tự chuyển tới trang chủ theo role (admin / staff / parent)
      }
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final api = ref.read(authApiProvider);
    try {
      OtpChallenge next;
      try {
        next = await api.resendOtp(_challenge.otpSessionId);
      } catch (_) {
        final email = widget.args.email;
        if (email == null) rethrow;
        next = await api.resendVerifyEmail(email);
      }
      if (!mounted) return;
      setState(() {
        _challenge = next;
        _startCountdown(next.resendAfter);
      });
      showSuccess(context, 'Đã gửi lại mã tới ${next.maskedEmail}');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.args.purpose == OtpPurpose.login;
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Xác thực đăng nhập' : 'Xác minh email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
              AppSpacing.gapMd,
              Text('Nhập mã 6 số đã gửi tới', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              Text(_challenge.maskedEmail, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              AppSpacing.gapLg,
              OtpInput(key: _otpKey, onCompleted: _verify),
              AppSpacing.gapLg,
              AppButton(
                label: isLogin ? 'Đăng nhập' : 'Xác minh',
                loading: _loading,
                onPressed: () => _verify(_otpKey.currentState?.code ?? ''),
              ),
              AppSpacing.gapMd,
              TextButton(
                onPressed: _seconds > 0 ? null : _resend,
                child: Text(_seconds > 0 ? 'Gửi lại mã sau $_seconds giây' : 'Gửi lại mã'),
              ),
              AppSpacing.gapMd,
              const InfoBanner(
                text: 'Không thấy mail? Kiểm tra mục Spam / Thư rác. Mã có hiệu lực 5 phút, nhập sai 5 lần sẽ bị huỷ.',
                icon: Icons.tips_and_updates_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
