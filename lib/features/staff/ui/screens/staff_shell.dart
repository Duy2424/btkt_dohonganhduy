// Dashboard nhân viên hỗ trợ: số liệu nhanh (hàng chờ / của tôi / đã xong) + 3 tab ticket.
// Chỉ hiện ticket của chính nhân viên đó + hàng chờ chưa ai nhận. Nhân viên không xem được vị trí / dữ liệu trẻ.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/account_menu.dart';
import '../../../auth/state/session_controller.dart';
import '../../../tickets/data/tickets_api.dart';
import '../../../tickets/ui/widgets/ticket_list_view.dart';

class StaffShell extends ConsumerWidget {
  const StaffShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(ticketsProvider(('queue', null))).value?.counts ?? const {};
    final user = ref.watch(sessionProvider).user;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Xin chào, ${user?.fullName ?? ''}'),
          actions: const [AccountMenu()],
          bottom: const TabBar(tabs: [Tab(text: 'Hàng chờ'), Tab(text: 'Của tôi'), Tab(text: 'Đã xong')]),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: Row(children: [
                _Stat('Hàng chờ', counts['queue'] ?? 0, AppColors.warning),
                AppSpacing.gapSm,
                _Stat('Đang xử lý', counts['mine'] ?? 0, AppColors.info),
                AppSpacing.gapSm,
                _Stat('Đã xong', counts['done'] ?? 0, AppColors.success),
              ]),
            ),
            const Expanded(
              child: TabBarView(children: [
                TicketListView(scope: 'queue', showStatusFilter: false, emptyMessage: 'Hàng chờ trống 🎉'),
                TicketListView(scope: 'mine', showStatusFilter: false, emptyMessage: 'Bạn chưa nhận ticket nào'),
                TicketListView(scope: 'done', showStatusFilter: false, emptyMessage: 'Chưa có ticket đã xong'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          color: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(children: [
              Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}
