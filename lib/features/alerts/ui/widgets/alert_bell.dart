// Chuông cảnh báo trên AppBar, badge = số cảnh báo chưa đọc.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/alerts_providers.dart';

class AlertBell extends ConsumerWidget {
  const AlertBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: 'Cảnh báo',
      onPressed: () => context.push('/parent/alerts'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
