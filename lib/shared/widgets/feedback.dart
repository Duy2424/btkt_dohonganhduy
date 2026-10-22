// Phản hồi cho người dùng: SnackBar tiếng Việt (thành công / lỗi) và hộp thoại xác nhận trước khi xoá.
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/network/api_exception.dart';

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.success,
    ));
}

void showError(BuildContext context, Object error) {
  final message = error is String ? error : ApiException.from(error).message;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.danger,
    ));
}

/// Hộp thoại xác nhận. Trả về true nếu người dùng đồng ý.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xoá',
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline,
          color: danger ? AppColors.danger : null, size: 36),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
