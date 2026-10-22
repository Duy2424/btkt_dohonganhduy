// Hộp thoại "Thoát chế độ con": phải nhập mật khẩu tài khoản của bố mẹ thì máy con mới thoát được.
// Đúng mật khẩu: server huỷ ghép và báo cho bố mẹ, máy tắt dịch vụ nền rồi quay về màn chọn loại máy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/state/session_controller.dart';
import '../../data/child_device_api.dart';

Future<void> showLeaveChildModeDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _LeaveChildModeDialog());

class _LeaveChildModeDialog extends ConsumerStatefulWidget {
  const _LeaveChildModeDialog();

  @override
  ConsumerState<_LeaveChildModeDialog> createState() => _LeaveChildModeDialogState();
}

class _LeaveChildModeDialogState extends ConsumerState<_LeaveChildModeDialog> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mật khẩu của bố mẹ');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(childDeviceApiProvider).leave(_password.text);
      // Lấy notifier trước khi đóng hộp thoại, sau khi đóng thì widget này không dùng ref được nữa
      final session = ref.read(sessionProvider.notifier);
      if (mounted) Navigator.pop(context);
      await session.unpairChild();
      await session.resetMode();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(Icons.logout, size: 36),
        title: const Text('Thoát chế độ con'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhờ bố mẹ nhập mật khẩu tài khoản của bố mẹ.'),
            AppSpacing.gapMd,
            AppTextField(
              controller: _password,
              label: 'Mật khẩu của bố mẹ',
              icon: Icons.lock_outline,
              obscure: true,
              serverError: _error,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Huỷ')),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Đang kiểm tra…' : 'Thoát')),
        ],
      );
}
