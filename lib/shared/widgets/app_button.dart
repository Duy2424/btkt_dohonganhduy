// Nút chính của app (giãn hết chiều ngang): tự khoá + hiện vòng xoay khi đang gửi (tránh bấm 2 lần).
import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final action = loading ? null : onPressed;
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(onPressed: action, child: child)
          : FilledButton(
              onPressed: action,
              style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
              child: child,
            ),
    );
  }
}
