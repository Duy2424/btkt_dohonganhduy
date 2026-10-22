// Thêm / sửa hồ sơ con: tên, năm sinh, tên trường, màu avatar. Kiểm tra ngay tại ô, nút Lưu khoá khi đang gửi.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../state/children_providers.dart';

class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({super.key, this.childId});
  final String? childId;

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _year = TextEditingController();
  final _school = TextEditingController();
  String _color = AppColors.toHex(AppColors.avatarChoices.first);
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final existing = (ref.read(childrenProvider).value ?? const []).where((c) => c.id == widget.childId).firstOrNull;
    if (existing != null) {
      _name.text = existing.name;
      _year.text = existing.birthYear?.toString() ?? '';
      _school.text = existing.schoolName;
      _color = existing.avatarColor;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _school.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'birthYear': _year.text.trim().isEmpty ? null : int.parse(_year.text.trim()),
      'schoolName': _school.text.trim(),
      'avatarColor': _color,
    };
    try {
      final notifier = ref.read(childrenProvider.notifier);
      if (widget.childId == null) {
        final child = await notifier.create(body);
        if (!mounted) return;
        showSuccess(context, 'Đã thêm hồ sơ ${child.name}');
        context.pushReplacement('/parent/children/${child.id}');
      } else {
        await notifier.edit(widget.childId!, body);
        if (!mounted) return;
        showSuccess(context, 'Đã cập nhật hồ sơ');
        context.pop();
      }
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      if (err.fieldErrors.isNotEmpty) {
        setState(() => _errors = err.fieldErrors);
      } else {
        showError(context, err);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.childId == null ? 'Thêm hồ sơ con' : 'Sửa hồ sơ con')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(child: ChildAvatar(name: _name.text, color: _color, radius: 40)),
            AppSpacing.gapLg,
            AppTextField(
              controller: _name,
              label: 'Tên con',
              icon: Icons.child_care,
              validator: (v) => Validators.maxLength(v, 40, 'tên con'),
              serverError: _errors['name'],
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _year,
              label: 'Năm sinh (tuỳ chọn)',
              icon: Icons.cake_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              validator: Validators.birthYear,
              serverError: _errors['birthYear'],
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _school,
              label: 'Tên trường (tuỳ chọn)',
              icon: Icons.school_outlined,
              validator: (v) => (v ?? '').length > 100 ? 'Tên trường tối đa 100 ký tự' : null,
            ),
            const SectionHeader('Màu avatar'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in AppColors.avatarChoices)
                  GestureDetector(
                    onTap: () => setState(() => _color = AppColors.toHex(c)),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: c,
                      child: AppColors.toHex(c) == _color.toUpperCase() ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  ),
              ],
            ),
            AppSpacing.gapXl,
            AppButton(label: 'Lưu', icon: Icons.save_outlined, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
