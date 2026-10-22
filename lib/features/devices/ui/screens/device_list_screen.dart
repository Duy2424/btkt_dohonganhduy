// Danh sách thiết bị của các con (CRUD thiết bị): trạng thái trực tuyến, pin; đổi tên, "Định vị ngay", huỷ ghép.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../children/state/children_providers.dart';
import '../../data/devices_api.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết bị của con')),
      body: AsyncListView<DeviceInfo>(
        value: ref.watch(devicesProvider),
        onRefresh: () => ref.refresh(devicesProvider.future),
        emptyMessage: 'Chưa có điện thoại nào được ghép.\nVào hồ sơ con → "Ghép" để tạo mã QR.',
        emptyIcon: Icons.phonelink_off,
        itemBuilder: (context, d) => Card(
          child: ListTile(
            leading: ChildAvatar(name: d.childName, color: d.childColor, online: d.online),
            title: Text(d.name),
            subtitle: Text(
              '${d.model}${d.androidVersion.isEmpty ? '' : ' · Android ${d.androidVersion}'}\n'
              '${d.online ? 'Trực tuyến' : 'Hoạt động ${AppDates.ago(d.lastSeenAt)}'}'
              '${d.batteryLevel == null ? '' : ' · Pin ${d.batteryLevel}%'}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (v) => _action(context, ref, d, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'locate', child: Text('Định vị ngay')),
                PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                PopupMenuItem(value: 'unpair', child: Text('Huỷ ghép', style: TextStyle(color: AppColors.danger))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, DeviceInfo d, String action) async {
    final api = ref.read(devicesApiProvider);
    try {
      switch (action) {
        case 'locate':
          await api.locateNow(d.id);
          if (context.mounted) showSuccess(context, 'Đã gửi yêu cầu, vị trí mới sẽ hiện sau vài giây');
        case 'rename':
          final name = await _askName(context, d.name);
          if (name == null) return;
          await api.rename(d.id, name);
          ref.invalidate(devicesProvider);
          if (context.mounted) showSuccess(context, 'Đã đổi tên thiết bị');
        case 'unpair':
          final ok = await confirmDialog(context,
              title: 'Huỷ ghép ${d.name}?', message: 'Máy của ${d.childName} sẽ ngừng chia sẻ vị trí.', confirmLabel: 'Huỷ ghép');
          if (!ok) return;
          await api.unpair(d.id);
          ref.invalidate(devicesProvider);
          ref.read(childrenProvider.notifier).refresh();
          if (context.mounted) showSuccess(context, 'Đã huỷ ghép');
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<String?> _askName(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    final form = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên thiết bị'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            maxLength: 40,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Vui lòng nhập tên thiết bị' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
