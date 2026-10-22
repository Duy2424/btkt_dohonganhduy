// Danh sách cảnh báo (CRUD cảnh báo): lọc theo con / loại / chưa đọc, chạm để đánh dấu đã đọc,
// vuốt để xoá, menu "Đọc tất cả" và "Xoá các cảnh báo đã đọc".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../children/state/children_providers.dart';
import '../../data/alerts_api.dart';
import '../../state/alerts_providers.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(alertFilterProvider);
    final children = ref.watch(childrenProvider).value ?? const [];
    final notifier = ref.read(alertsProvider.notifier);
    final page = ref.watch(alertsProvider);

    Future<void> run(Future<void> Function() action, String done) async {
      try {
        await action();
        if (context.mounted) showSuccess(context, done);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'read'
                ? run(notifier.markAllRead, 'Đã đánh dấu tất cả là đã đọc')
                : run(notifier.removeRead, 'Đã xoá các cảnh báo đã đọc'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'read', child: Text('Đọc tất cả')),
              PopupMenuItem(value: 'delete', child: Text('Xoá các cảnh báo đã đọc')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              children: [
                FilterChip(
                  label: const Text('Chưa đọc'),
                  selected: filter.unreadOnly,
                  onSelected: (v) => ref.read(alertFilterProvider.notifier).set(filter.copyWith(unreadOnly: v)),
                ),
                const SizedBox(width: 8),
                _Dropdown(
                  hint: 'Tất cả con',
                  value: filter.childId,
                  items: {for (final c in children) c.id: c.name},
                  onChanged: (v) => ref.read(alertFilterProvider.notifier).set(filter.copyWith(childId: v, clearChild: v == null)),
                ),
                const SizedBox(width: 8),
                _Dropdown(
                  hint: 'Mọi loại',
                  value: filter.type,
                  items: {for (final t in Labels.alertTypes) t: Labels.alertType(t)},
                  onChanged: (v) => ref.read(alertFilterProvider.notifier).set(filter.copyWith(type: v, clearType: v == null)),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncListView<AlertItem>(
              value: page.whenData((p) => p.items),
              onRefresh: notifier.refresh,
              emptyMessage: 'Không có cảnh báo nào 🎉',
              emptyIcon: Icons.notifications_none,
              itemBuilder: (context, a) => Dismissible(
                key: ValueKey(a.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppSpacing.radius)),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => confirmDialog(context, title: 'Xoá cảnh báo?', message: a.title),
                onDismissed: (_) => run(() => notifier.remove(a.id), 'Đã xoá cảnh báo'),
                child: _AlertTile(alert: a, onTap: a.unread ? () => run(() => notifier.markRead(a.id), 'Đã đánh dấu đã đọc') : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, this.onTap});
  final AlertItem alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forLevel(alert.level);
    final icon = switch (alert.level) { 'danger' => Icons.warning_rounded, 'warning' => Icons.error_outline, _ => Icons.info_outline };
    return Card(
      color: alert.unread ? color.withValues(alpha: 0.08) : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.18), child: Icon(icon, color: color)),
        title: Text('${alert.childName.isEmpty ? '' : '${alert.childName}: '}${alert.title}',
            style: TextStyle(fontWeight: alert.unread ? FontWeight.w700 : FontWeight.w400)),
        subtitle: Text('${alert.message}\n${Labels.alertType(alert.type)} · ${AppDates.dmyHm(alert.createdAt)}'),
        isThreeLine: true,
        trailing: alert.unread ? Icon(Icons.circle, size: 10, color: color) : null,
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.hint, required this.value, required this.items, required this.onChanged});
  final String hint;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: Text(hint),
      underline: const SizedBox(),
      borderRadius: BorderRadius.circular(12),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(hint)),
        for (final e in items.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
      ],
      onChanged: onChanged,
    );
  }
}
