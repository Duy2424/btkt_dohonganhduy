// Chi tiết ticket (mọi role): tin nhắn qua lại, ô trả lời; nhân viên "Nhận ticket" + đổi trạng thái
// (Mới → Đang xử lý → Đã giải quyết → Đã đóng); phụ huynh xoá khi còn "Mới"; admin xoá bất kỳ.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/state/session_controller.dart';
import '../../data/tickets_api.dart';
import '../widgets/ticket_list_view.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(TicketsApi api) action, String done) async {
    setState(() => _sending = true);
    try {
      await action(ref.read(ticketsApiProvider));
      ref.invalidate(ticketDetailProvider(widget.ticketId));
      ref.invalidate(ticketsProvider);
      if (mounted) showSuccess(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketDetailProvider(widget.ticketId));
    final me = ref.watch(sessionProvider).user!;
    final t = async.value;
    final isStaff = me.role == 'staff';
    final mine = t?.assignedStaffId == me.id;
    final canDelete = t != null && (me.role == 'admin' || (me.role == 'parent' && t.status == 'open'));
    const order = ['open', 'in_progress', 'resolved', 'closed'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết ticket'),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'Xoá ticket?', message: t.subject);
                if (!ok) return;
                await _run((api) => api.delete(t.id), 'Đã xoá ticket');
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingSkeleton(itemCount: 3),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(ticketDetailProvider(widget.ticketId))),
        data: (t) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(ticketDetailProvider(widget.ticketId).future),
                child: ListView(
                  padding: AppSpacing.page,
                  children: [
                    Text(t.subject, style: Theme.of(context).textTheme.titleLarge),
                    AppSpacing.gapSm,
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      StatusChip(label: Labels.ticketStatus(t.status), color: ticketStatusColor(t.status)),
                      StatusChip(label: Labels.ticketCategory(t.category), color: Theme.of(context).colorScheme.primary),
                      StatusChip(label: t.assignedStaffName == null ? 'Chưa có người nhận' : 'NV: ${t.assignedStaffName}',
                          color: Theme.of(context).colorScheme.tertiary),
                    ]),
                    if (isStaff && t.assignedStaffId == null && t.status == 'open') ...[
                      AppSpacing.gapMd,
                      FilledButton.icon(
                        onPressed: _sending ? null : () => _run((api) => api.claim(t.id), 'Đã nhận ticket'),
                        icon: const Icon(Icons.assignment_ind_outlined),
                        label: const Text('Nhận ticket này'),
                      ),
                    ],
                    if ((isStaff && mine) || me.role == 'admin') ...[
                      AppSpacing.gapMd,
                      Wrap(spacing: 8, children: [
                        for (final s in order.where((s) => me.role == 'admin' ? s != t.status : order.indexOf(s) > order.indexOf(t.status)))
                          OutlinedButton(
                            onPressed: _sending ? null : () => _run((api) => api.setStatus(t.id, s), 'Đã chuyển sang "${Labels.ticketStatus(s)}"'),
                            child: Text('→ ${Labels.ticketStatus(s)}'),
                          ),
                      ]),
                    ],
                    const SectionHeader('Trao đổi'),
                    for (final m in t.messages) _Bubble(message: m, mine: m.senderId == me.id),
                  ],
                ),
              ),
            ),
            if (t.status != 'closed' && (!isStaff || mine))
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(hintText: 'Nhập tin nhắn...'),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _sending
                          ? null
                          : () {
                              final text = _reply.text.trim();
                              if (text.isEmpty) return showError(context, 'Vui lòng nhập nội dung');
                              _run((api) => api.sendMessage(t.id, text), 'Đã gửi tin nhắn').then((_) => _reply.clear());
                            },
                      icon: const Icon(Icons.send),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final TicketMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${message.senderName} · ${Labels.role(message.senderRole)}', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(message.content),
          const SizedBox(height: 4),
          Text(AppDates.dmyHm(message.createdAt), style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}
