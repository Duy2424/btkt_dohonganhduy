// Màn đầu tiên khi mở app: chọn "Máy phụ huynh / nhân viên" (đăng nhập tài khoản) hoặc "Máy của con" (ghép QR).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/storage/local_prefs.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/state/session_controller.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const AppLogo(size: 88),
              AppSpacing.gapLg,
              Text('Điện thoại này dùng cho ai?', style: text.titleLarge, textAlign: TextAlign.center),
              AppSpacing.gapXl,
              _ModeCard(
                icon: Icons.family_restroom_rounded,
                title: 'Máy phụ huynh / nhân viên',
                onTap: () => ref.read(sessionProvider.notifier).chooseMode(AppMode.parent),
              ),
              AppSpacing.gapMd,
              _ModeCard(
                icon: Icons.child_care_rounded,
                title: 'Máy của con',
                onTap: () => ref.read(sessionProvider.notifier).chooseMode(AppMode.child),
              ),
              const Spacer(flex: 2),
              Text('Đồ án btkt_dohonganhduy · Đỗ Hồng Anh Duy', style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, size: 30, color: scheme.onPrimaryContainer),
              ),
              AppSpacing.gapMd,
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
