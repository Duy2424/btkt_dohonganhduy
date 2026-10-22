// Thời khoá biểu dạng lưới tuần (T2…CN) + danh sách buổi học để sửa / xoá.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../data/school_sessions_api.dart';

class TimetableView extends ConsumerWidget {
  const TimetableView({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(schoolSessionsProvider(childId));
    final sessions = async.value ?? const <SchoolSession>[];
    return AsyncListView<SchoolSession>(
      value: async,
      onRefresh: () => ref.refresh(schoolSessionsProvider(childId).future),
      emptyMessage: 'Chưa có buổi học nào.\nThêm vùng "Trường" cho con, rồi thêm buổi học để bật Giờ học an toàn.',
      emptyIcon: Icons.school_outlined,
      header: sessions.isEmpty ? null : _WeekGrid(sessions: sessions),
      itemBuilder: (context, s) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.info.withValues(alpha: 0.15),
            child: const Icon(Icons.school, color: AppColors.info),
          ),
          title: Text('${s.label.isEmpty ? 'Buổi học' : s.label} · ${s.startTime}–${s.endTime}'),
          subtitle: Text('${AppDates.days(s.daysOfWeek)} · ${s.geofenceName}\n'
              'Cho phép trễ ${s.graceMinutes} phút · ra ngoài ≥ ${s.outsideToleranceMinutes} phút thì báo'),
          isThreeLine: true,
          onTap: () => context.push('/parent/children/$childId/sessions/form', extra: s),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Xoá buổi học?', message: '${s.label} ${s.startTime}–${s.endTime}');
              if (!ok) return;
              try {
                await ref.read(schoolSessionsApiProvider).delete(s.id);
                ref.invalidate(schoolSessionsProvider(childId));
                if (context.mounted) showSuccess(context, 'Đã xoá buổi học');
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.sessions});
  final List<SchoolSession> sessions;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var d = 1; d <= 7; d++)
              Expanded(
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: d == today ? scheme.primary : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(AppDates.dayShort[d],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700, color: d == today ? scheme.onPrimary : null)),
                  ),
                  const SizedBox(height: 4),
                  for (final s in sessions.where((s) => s.daysOfWeek.contains(d)))
                    Container(
                      margin: const EdgeInsets.all(2),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: s.active ? 0.18 : 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${s.startTime}\n${s.endTime}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
