// Tab "Thống kê" của admin: người dùng theo role, thiết bị online 15 phút qua, cảnh báo hôm nay, ticket đang mở.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../data/admin_api.dart';

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(adminStatsProvider).when(
          loading: () => const LoadingSkeleton(itemCount: 4, itemHeight: 100),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(adminStatsProvider)),
          data: (s) => RefreshIndicator(
            onRefresh: () => ref.refresh(adminStatsProvider.future),
            child: GridView.count(
              padding: AppSpacing.page,
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.35,
              children: [
                _StatCard('Phụ huynh', '${s.parents}', Icons.family_restroom, AppColors.seed),
                _StatCard('Nhân viên', '${s.staff}', Icons.support_agent, AppColors.info),
                _StatCard('Quản trị viên', '${s.admins}', Icons.admin_panel_settings, Colors.indigo),
                _StatCard('Tài khoản bị khoá', '${s.locked}', Icons.lock_person, AppColors.danger),
                _StatCard('Thiết bị online (15 phút)', '${s.devicesOnline}/${s.devicesTotal}', Icons.phone_android, AppColors.success),
                _StatCard('Cảnh báo hôm nay', '${s.alertsToday}', Icons.notifications_active, AppColors.warning),
                _StatCard('Ticket mới', '${s.ticketsOpen}', Icons.mark_email_unread, AppColors.warning),
                _StatCard('Ticket đang xử lý', '${s.ticketsInProgress}', Icons.pending_actions, AppColors.info),
              ],
            ),
          ),
        );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
          ],
        ),
      ),
    );
  }
}
