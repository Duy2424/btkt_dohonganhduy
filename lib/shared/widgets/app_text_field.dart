// Ô nhập dùng chung: nhãn, icon, kiểm tra ngay khi gõ, hiện/ẩn mật khẩu, hiển thị lỗi từ server (serverError).
// plainAscii dùng cho ô tên đăng nhập và email: tắt gõ Telex, gợi ý, tự sửa (tránh "parent01" thành "pảent01").
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.validator,
    this.serverError,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onSubmitted,
    this.hint,
    this.enabled = true,
    this.autofillHints,
    this.plainAscii = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? Function(String?)? validator;
  final String? serverError;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final bool plainAscii;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      enabled: widget.enabled,
      keyboardType: widget.plainAscii && widget.keyboardType == null ? TextInputType.visiblePassword : widget.keyboardType,
      autocorrect: !(widget.plainAscii || widget.obscure),
      enableSuggestions: !(widget.plainAscii || widget.obscure),
      textInputAction: widget.textInputAction,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        errorText: widget.serverError,
        errorMaxLines: 3,
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
