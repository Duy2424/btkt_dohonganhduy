// Phụ huynh tạo ticket hỗ trợ: tiêu đề, loại (Tài khoản / Thiết bị / Báo lỗi / Khác), nội dung.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/tickets_api.dart';

class TicketFormScreen extends ConsumerStatefulWidget {
  const TicketFormScreen({super.key});

  @override
  ConsumerState<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends ConsumerState<TicketFormScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _content = TextEditingController();
  String _category = 'device';
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _subject.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errors = {};
    });
    try {
      final t = await ref.read(ticketsApiProvider).create(_subject.text.trim(), _category, _content.text.trim());
      if (!mounted) return;
      showSuccess(context, 'Đã gửi yêu cầu hỗ trợ');
      context.pushReplacement('/tickets/${t.id}');
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
      appBar: AppBar(title: const Text('Gửi yêu cầu hỗ trợ')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppTextField(
              controller: _subject,
              label: 'Tiêu đề',
              icon: Icons.title,
              maxLength: 100,
              serverError: _errors['subject'],
              validator: (v) => (v ?? '').trim().length < 5 ? 'Tiêu đề tối thiểu 5 ký tự' : null,
            ),
            AppSpacing.gapSm,
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Loại', prefixIcon: Icon(Icons.category_outlined)),
              items: [
                for (final c in ['account', 'device', 'bug', 'other'])
                  DropdownMenuItem(value: c, child: Text(Labels.ticketCategory(c))),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _content,
              label: 'Nội dung',
              icon: Icons.notes,
              maxLines: 6,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              serverError: _errors['content'],
              validator: (v) => (v ?? '').trim().length < 10 ? 'Nội dung tối thiểu 10 ký tự' : null,
            ),
            AppSpacing.gapLg,
            AppButton(label: 'Gửi', icon: Icons.send, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
