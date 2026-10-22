// Tab "Cài đặt" của phụ huynh: tài khoản, đăng nhập khuôn mặt, thiết bị của con, hỗ trợ (ticket), giới thiệu, đăng xuất.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../auth/state/session_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    return ListView(
      padding: AppSpacing.page,
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.fullName ?? ''),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/account'),
          ),
        ),
        AppSpacing.gapMd,
        Card(
          child: Column(children: [
            _tile(context, Icons.face_retouching_natural, 'Đăng nhập bằng khuôn mặt', '/face-setup'),
            _tile(context, Icons.phone_android, 'Thiết bị của con', '/parent/devices'),
            _tile(context, Icons.support_agent, 'Hỗ trợ (ticket)', '/parent/tickets'),
            _tile(context, Icons.info_outline, 'Giới thiệu', '/about'),
          ]),
        ),
        AppSpacing.gapLg,
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
          onPressed: () async {
            final ok = await confirmDialog(context, title: 'Đăng xuất?', message: 'Bạn sẽ cần đăng nhập lại.', confirmLabel: 'Đăng xuất', danger: false);
            if (ok) ref.read(sessionProvider.notifier).logout();
          },
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String path) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(path),
      );
}
