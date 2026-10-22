// Danh sách lịch khoá máy của 1 con: nhãn "Đang hiệu lực", bật/tắt nhanh bằng switch, sửa, xoá.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../data/lock_schedules_api.dart';

class LockScheduleList extends ConsumerWidget {
  const LockScheduleList({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncListView<LockSchedule>(
      value: ref.watch(lockSchedulesProvider(childId)),
      onRefresh: () => ref.refresh(lockSchedulesProvider(childId).future),
      emptyMessage: 'Chưa có lịch khoá máy.\nVí dụ: "Giờ ngủ" 21:30 – 06:30 hằng ngày.',
      emptyIcon: Icons.lock_clock_outlined,
      itemBuilder: (context, l) => Card(
        child: ListTile(
          leading: Icon(Icons.lock_clock, color: l.activeNow ? AppColors.danger : null),
          title: Row(children: [
            Flexible(child: Text(l.name, overflow: TextOverflow.ellipsis)),
            if (l.activeNow) ...[const SizedBox(width: 8), const StatusChip(label: 'Đang hiệu lực', color: AppColors.danger)],
          ]),
          subtitle: Text('${l.startTime} – ${l.endTime} · ${AppDates.days(l.daysOfWeek)}'
              '${l.allowedPackages.isEmpty ? '' : '\nThêm ${l.allowedPackages.length} app được phép'}'),
          isThreeLine: l.allowedPackages.isNotEmpty,
          onTap: () => context.push('/parent/children/$childId/locks/form', extra: l),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Switch(
              value: l.enabled,
              onChanged: (v) async {
                try {
                  await ref.read(lockSchedulesApiProvider).update(l.id, {'enabled': v});
                  ref.invalidate(lockSchedulesProvider(childId));
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'Xoá lịch "${l.name}"?', message: 'Máy của con sẽ không bị khoá theo lịch này nữa.');
                if (!ok) return;
                try {
                  await ref.read(lockSchedulesApiProvider).delete(l.id);
                  ref.invalidate(lockSchedulesProvider(childId));
                  if (context.mounted) showSuccess(context, 'Đã xoá lịch khoá');
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
          ]),
        ),
      ),
    );
  }
}
