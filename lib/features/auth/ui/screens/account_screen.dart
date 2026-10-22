// Tài khoản của tôi (mọi role): sửa họ tên / số điện thoại, đổi mật khẩu, đăng xuất.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/auth_api.dart';
import '../../state/session_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final _user = ref.read(sessionProvider).user!;
  late final _fullName = TextEditingController(text: _user.fullName);
  late final _phone = TextEditingController(text: _user.phone);
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  String? _currentError;

  @override
  void dispose() {
    for (final c in [_fullName, _phone, _current, _newPass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      final user = await ref.read(authApiProvider).updateMe(fullName: _fullName.text.trim(), phone: _phone.text.trim());
      ref.read(sessionProvider.notifier).updateUser(user);
      if (mounted) showSuccess(context, 'Đã cập nhật thông tin');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    setState(() => _currentError = null);
    if (!_passwordForm.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      await ref.read(authApiProvider).changePassword(_current.text, _newPass.text);
      _current.clear();
      _newPass.clear();
      if (mounted) showSuccess(context, 'Đổi mật khẩu thành công');
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      if (err.fieldErrors['currentPassword'] != null) {
        setState(() => _currentError = err.fieldErrors['currentPassword']);
      } else {
        showError(context, err);
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản của tôi')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('@${_user.username}'),
              subtitle: Text('${_user.email}\n${Labels.role(_user.role)}'),
              isThreeLine: true,
            ),
          ),
          const SectionHeader('Thông tin cá nhân'),
          Form(
            key: _profileForm,
            child: Column(children: [
              AppTextField(controller: _fullName, label: 'Họ và tên', icon: Icons.badge_outlined, validator: Validators.fullName),
              AppSpacing.gapMd,
              AppTextField(controller: _phone, label: 'Số điện thoại', icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone, validator: Validators.phone),
              AppSpacing.gapMd,
              AppButton(label: 'Lưu thông tin', loading: _savingProfile, onPressed: _saveProfile),
            ]),
          ),
          const SectionHeader('Đổi mật khẩu'),
          Form(
            key: _passwordForm,
            child: Column(children: [
              AppTextField(controller: _current, label: 'Mật khẩu hiện tại', icon: Icons.lock_outline, obscure: true,
                  validator: (v) => Validators.required(v, 'mật khẩu hiện tại'), serverError: _currentError),
              AppSpacing.gapMd,
              AppTextField(controller: _newPass, label: 'Mật khẩu mới', icon: Icons.lock_reset, obscure: true,
                  validator: Validators.password),
              AppSpacing.gapMd,
              AppButton(label: 'Đổi mật khẩu', outlined: true, loading: _savingPassword, onPressed: _changePassword),
            ]),
          ),
          AppSpacing.gapXl,
          AppButton(
            label: 'Đăng xuất',
            icon: Icons.logout,
            color: Theme.of(context).colorScheme.error,
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
