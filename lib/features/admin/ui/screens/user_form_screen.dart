// Admin tạo / sửa người dùng: họ tên, username, email, số điện thoại, vai trò, mật khẩu (khi tạo).
// Tài khoản admin tạo được kích hoạt ngay (không cần xác minh email).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../auth/data/models/app_user.dart';
import '../../data/admin_api.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.user});
  final AppUser? user;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.user?.fullName ?? '');
  late final _username = TextEditingController(text: widget.user?.username ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _phone = TextEditingController(text: widget.user?.phone ?? '');
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'staff';
  bool _saving = false;
  Map<String, String> _errors = {};

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    for (final c in [_fullName, _username, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(adminApiProvider);
    try {
      if (_isEdit) {
        await api.updateUser(widget.user!.id, {
          'fullName': _fullName.text.trim(),
          'email': _email.text.trim().toLowerCase(),
          'phone': _phone.text.trim(),
          'role': _role,
        });
      } else {
        await api.createUser({
          'fullName': _fullName.text.trim(),
          'username': _username.text.trim().toLowerCase(),
          'email': _email.text.trim().toLowerCase(),
          'phone': _phone.text.trim(),
          'password': _password.text,
          'role': _role,
        });
      }
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      showSuccess(context, _isEdit ? 'Đã cập nhật người dùng' : 'Đã tạo người dùng');
      context.pop();
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      setState(() => _errors = err.fieldErrors);
      if (err.fieldErrors.isEmpty) showError(context, err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa người dùng' : 'Thêm người dùng')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppTextField(controller: _fullName, label: 'Họ và tên', icon: Icons.badge_outlined,
                validator: Validators.fullName, serverError: _errors['fullName']),
            AppSpacing.gapMd,
            AppTextField(controller: _username, label: 'Tên đăng nhập', icon: Icons.person_outline, enabled: !_isEdit, plainAscii: true,
                validator: Validators.username, serverError: _errors['username']),
            AppSpacing.gapMd,
            AppTextField(controller: _email, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, plainAscii: true,
                validator: Validators.email, serverError: _errors['email']),
            AppSpacing.gapMd,
            AppTextField(controller: _phone, label: 'Số điện thoại', icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
                validator: Validators.phone, serverError: _errors['phone']),
            AppSpacing.gapMd,
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Vai trò', prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
              items: [for (final r in ['admin', 'staff', 'parent']) DropdownMenuItem(value: r, child: Text(Labels.role(r)))],
              onChanged: (v) => setState(() => _role = v!),
            ),
            if (!_isEdit) ...[
              AppSpacing.gapMd,
              AppTextField(controller: _password, label: 'Mật khẩu', icon: Icons.lock_outline, obscure: true,
                  validator: Validators.password, serverError: _errors['password']),
            ],
            AppSpacing.gapLg,
            AppButton(label: 'Lưu', icon: Icons.save_outlined, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
