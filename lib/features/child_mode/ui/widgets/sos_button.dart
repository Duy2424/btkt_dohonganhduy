// Nút SOS to: phải giữ 2 giây mới gửi (tránh bấm nhầm), có vòng tiến trình chạy quanh nút.
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.onTriggered});
  final Future<void> Function() onTriggered;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..addStatusListener((s) async {
      if (s == AnimationStatus.completed) {
        setState(() => _sending = true);
        await widget.onTriggered();
        if (mounted) {
          setState(() => _sending = false);
          _ctrl.reset();
        }
      }
    });
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _sending ? null : _ctrl.forward(),
      onLongPressEnd: (_) {
        if (!_ctrl.isCompleted) _ctrl.reverse();
      },
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(value: _ctrl.value, strokeWidth: 10, color: AppColors.danger),
              ),
            ),
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.4), blurRadius: 24)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _sending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800)),
                  const Text('Giữ 2 giây', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
