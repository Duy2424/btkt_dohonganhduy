// Ô nhập OTP 6 ô: gõ tự nhảy sang ô kế, xoá tự lùi về ô trước, dán cả mã 6 số vào ô đầu cũng được.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatefulWidget {
  const OtpInput({super.key, required this.onCompleted, this.onChanged, this.length = 6});
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final int length;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late final _controllers = List.generate(widget.length, (_) => TextEditingController());
  late final _nodes = List.generate(widget.length, (_) => FocusNode());

  String get code => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onChanged(int i, String value) {
    if (value.length > 1) {
      // Dán cả mã
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var k = 0; k < widget.length; k++) {
        _controllers[k].text = k < digits.length ? digits[k] : '';
      }
      _nodes[(digits.length.clamp(1, widget.length)) - 1].requestFocus();
    } else if (value.isNotEmpty && i < widget.length - 1) {
      _nodes[i + 1].requestFocus();
    }
    widget.onChanged?.call(code);
    if (code.length == widget.length) widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 48,
          child: KeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKeyEvent: (e) {
              if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.backspace &&
                  _controllers[i].text.isEmpty && i > 0) {
                _controllers[i - 1].clear();
                _nodes[i - 1].requestFocus();
              }
            },
            child: TextField(
              controller: _controllers[i],
              focusNode: _nodes[i],
              autofocus: i == 0,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
              ),
              onChanged: (v) => _onChanged(i, v),
            ),
          ),
        );
      }),
    );
  }
}
