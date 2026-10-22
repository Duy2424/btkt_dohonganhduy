// Tab "Lịch" của phụ huynh: chọn con → "Thời khoá biểu" (lưới tuần, dữ liệu cho Giờ học an toàn) hoặc "Khoá máy".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../children/state/children_providers.dart';
import '../../../lock_schedules/ui/widgets/lock_schedule_list.dart';
import '../widgets/timetable_view.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(childrenProvider);
    final children = async.value ?? const [];
    final selected = ref.watch(selectedChildProvider);
    if (async.isLoading && children.isEmpty) return const LoadingSkeleton();
    if (async.hasError && children.isEmpty) {
      return ErrorView(error: async.error!, onRetry: () => ref.read(childrenProvider.notifier).refresh());
    }
    if (selected == null) return const EmptyView(message: 'Thêm hồ sơ con trước để tạo lịch', icon: Icons.event_busy);

    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              children: [
                for (final c in children)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: ChildAvatar(name: c.name, color: c.avatarColor, radius: 12),
                      label: Text(c.name),
                      selected: c.id == selected.id,
                      onSelected: (_) => ref.read(selectedChildIdProvider.notifier).select(c.id),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Thời khoá biểu'), icon: Icon(Icons.school_outlined)),
                ButtonSegment(value: 1, label: Text('Khoá máy'), icon: Icon(Icons.lock_clock_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(child: _tab == 0 ? TimetableView(childId: selected.id) : LockScheduleList(childId: selected.id)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'schedule-add',
        onPressed: () => context.push('/parent/children/${selected.id}/${_tab == 0 ? 'sessions' : 'locks'}/form'),
        icon: const Icon(Icons.add),
        label: Text(_tab == 0 ? 'Thêm buổi học' : 'Thêm lịch khoá'),
      ),
    );
  }
}
