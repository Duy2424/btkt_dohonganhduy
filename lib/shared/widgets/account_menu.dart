// Menu tài khoản trên AppBar dùng chung cho admin / nhân viên: tài khoản, khuôn mặt, giới thiệu, đăng xuất.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/state/session_controller.dart';

class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        icon: const Icon(Icons.account_circle_outlined),
        tooltip: 'Tài khoản',
        onSelected: (v) => v == 'logout' ? ref.read(sessionProvider.notifier).logout() : context.push(v),
        itemBuilder: (_) => const [
          PopupMenuItem(value: '/account', child: Text('Tài khoản của tôi')),
          PopupMenuItem(value: '/face-setup', child: Text('Đăng nhập bằng khuôn mặt')),
          PopupMenuItem(value: '/about', child: Text('Giới thiệu')),
          PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
        ],
      );
}
