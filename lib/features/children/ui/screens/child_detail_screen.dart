// Chi tiết một con: vị trí cuối, pin, thiết bị (ghép QR / huỷ ghép), vùng an toàn, "Hôm nay con nghỉ học",
// sửa và xoá (xoá kèm toàn bộ dữ liệu, hộp thoại có cảnh báo rõ).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../devices/data/devices_api.dart';
import '../../data/children_api.dart';
import '../../data/models/child_profile.dart';
import '../../state/children_providers.dart';

class ChildDetailScreen extends ConsumerWidget {
  const ChildDetailScreen({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(childrenProvider);
    final child = async.value?.where((c) => c.id == childId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(child?.name ?? 'Hồ sơ con'),
        actions: [
          if (child != null) ...[
            IconButton(tooltip: 'Sửa', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/parent/children/$childId/edit')),
            IconButton(tooltip: 'Xoá', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, child)),
          ],
        ],
      ),
      body: async.isLoading && child == null
          ? const LoadingSkeleton(itemCount: 3, itemHeight: 120)
          : child == null
              ? ErrorView(error: 'Không tìm thấy hồ sơ con', onRetry: () => ref.read(childrenProvider.notifier).refresh())
              : RefreshIndicator(
                  onRefresh: () => ref.read(childrenProvider.notifier).refresh(),
                  child: _Body(child: child),
                ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ChildProfile child) async {
    final ok = await confirmDialog(
      context,
      title: 'Xoá hồ sơ ${child.name}?',
      message: 'Toàn bộ dữ liệu liên quan sẽ bị xoá vĩnh viễn: lịch sử vị trí, vùng an toàn, thời khoá biểu, '
          'lịch khoá máy, cảnh báo. Điện thoại của con (nếu có) sẽ bị huỷ ghép.',
      confirmLabel: 'Xoá vĩnh viễn',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(childrenProvider.notifier).remove(child.id);
      if (!context.mounted) return;
      showSuccess(context, 'Đã xoá hồ sơ ${child.name}');
      context.pop();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = AppDates.ymd(DateTime.now());
    final offToday = child.schoolOffDates.contains(today);
    final device = child.device;
    return ListView(
      padding: AppSpacing.page,
      children: [
        Card(
          child: ListTile(
            leading: ChildAvatar(name: child.name, color: child.avatarColor, online: device?.online),
            title: Text(child.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text([
              if (child.birthYear != null) 'Sinh năm ${child.birthYear}',
              if (child.schoolName.isNotEmpty) child.schoolName,
            ].join(' · ')),
          ),
        ),
        const SectionHeader('Vị trí'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(child.placeName),
            subtitle: Text(child.lastLocation == null
                ? 'Chưa nhận được vị trí nào'
                : 'Cập nhật ${AppDates.ago(child.lastLocation!.at)} · sai số ${child.lastLocation!.accuracy?.round() ?? '?'} m'),
          ),
        ),
        const SectionHeader('Điện thoại của con'),
        Card(
          child: device == null
              ? ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text('Chưa ghép điện thoại'),
                  trailing: FilledButton(
                    onPressed: () => context.push('/parent/children/${child.id}/pair'),
                    child: const Text('Ghép'),
                  ),
                )
              : Column(children: [
                  ListTile(
                    leading: Icon(Icons.phone_android, color: device.online ? AppColors.success : AppColors.offline),
                    title: Text(device.name),
                    subtitle: Text('${device.model} · ${device.online ? 'Trực tuyến' : 'Hoạt động ${AppDates.ago(device.lastSeenAt)}'}'
                        '${device.batteryLevel != null ? ' · Pin ${device.batteryLevel}%' : ''}'),
                  ),
                  OverflowBar(alignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => context.push('/parent/children/${child.id}/pair'), child: const Text('Ghép máy khác')),
                    TextButton(
                      onPressed: () => _unpair(context, ref, device.id),
                      child: Text('Huỷ ghép', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  ]),
                ]),
        ),
        const SectionHeader('Quản lý'),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.radar),
              title: const Text('Vùng an toàn'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/parent/children/${child.id}/geofences'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.beach_access_outlined),
              title: const Text('Hôm nay con nghỉ học'),
              value: offToday,
              onChanged: (v) => _toggleOff(context, ref, today, v),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _toggleOff(BuildContext context, WidgetRef ref, String date, bool off) async {
    try {
      final api = ref.read(childrenApiProvider);
      off ? await api.addOffDate(child.id, date) : await api.removeOffDate(child.id, date);
      await ref.read(childrenProvider.notifier).refresh();
      if (context.mounted) showSuccess(context, off ? 'Đã đánh dấu hôm nay con nghỉ học' : 'Đã bỏ đánh dấu nghỉ học');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _unpair(BuildContext context, WidgetRef ref, String deviceId) async {
    final ok = await confirmDialog(context,
        title: 'Huỷ ghép điện thoại?', message: 'Máy của con sẽ ngừng chia sẻ vị trí và quay về màn hình quét QR.', confirmLabel: 'Huỷ ghép');
    if (!ok) return;
    try {
      await ref.read(devicesApiProvider).unpair(deviceId);
      await ref.read(childrenProvider.notifier).refresh();
      ref.invalidate(devicesProvider);
      if (context.mounted) showSuccess(context, 'Đã huỷ ghép thiết bị');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
