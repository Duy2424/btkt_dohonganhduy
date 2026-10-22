// Danh sách ticket dùng chung (phụ huynh / nhân viên / admin): lọc trạng thái, 4 trạng thái hiển thị, chạm để xem chi tiết.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../data/tickets_api.dart';

Color ticketStatusColor(String s) => switch (s) {
      'open' => AppColors.warning,
      'in_progress' => AppColors.info,
      'resolved' => AppColors.success,
      _ => AppColors.offline,
    };

class TicketListView extends ConsumerStatefulWidget {
  const TicketListView({super.key, this.scope = 'all', this.showStatusFilter = true, this.emptyMessage = 'Chưa có ticket nào'});
  final String scope;
  final bool showStatusFilter;
  final String emptyMessage;

  @override
  ConsumerState<TicketListView> createState() => _TicketListViewState();
}

class _TicketListViewState extends ConsumerState<TicketListView> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final key = (widget.scope, _status);
    return Column(
      children: [
        if (widget.showStatusFilter)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              children: [
                for (final s in [null, 'open', 'in_progress', 'resolved', 'closed'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s == null ? 'Tất cả' : Labels.ticketStatus(s)),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: AsyncListView<Ticket>(
            value: ref.watch(ticketsProvider(key)).whenData((p) => p.items),
            onRefresh: () => ref.refresh(ticketsProvider(key).future),
            emptyMessage: widget.emptyMessage,
            emptyIcon: Icons.support_agent,
            itemBuilder: (context, t) => Card(
              child: ListTile(
                onTap: () async {
                  await context.push('/tickets/${t.id}');
                  ref.invalidate(ticketsProvider);
                },
                title: Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${Labels.ticketCategory(t.category)} · ${t.parentName}'
                    '${t.assignedStaffName != null ? ' → ${t.assignedStaffName}' : ''}\n'
                    '${t.lastMessage} · ${AppDates.ago(t.updatedAt)}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: StatusChip(label: Labels.ticketStatus(t.status), color: ticketStatusColor(t.status)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
