// Thẻ con ở tab Tổng quan: avatar màu + chấm trực tuyến, "Ở trường / Ở nhà / Ngoài vùng", % pin,
// "cập nhật X phút trước" và cảnh báo mới nhất.
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../data/models/child_profile.dart';

class ChildCard extends StatelessWidget {
  const ChildCard({super.key, required this.child, this.onTap});
  final ChildProfile child;
  final VoidCallback? onTap;

  (IconData, Color) _place() => switch (child.placeType) {
        'school' => (Icons.school, AppColors.info),
        'home' => (Icons.home, AppColors.success),
        'other' => (Icons.place, AppColors.seed),
        'outside' => (Icons.wrong_location, AppColors.warning),
        _ => (Icons.location_disabled, AppColors.offline),
      };

  @override
  Widget build(BuildContext context) {
    final device = child.device;
    final text = Theme.of(context).textTheme;
    final (placeIcon, placeColor) = _place();
    final battery = device?.batteryLevel ?? child.lastLocation?.battery;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChildAvatar(name: child.name, color: child.avatarColor, radius: 26, online: device?.online),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name, style: text.titleMedium),
                        Text(
                          device == null
                              ? 'Chưa ghép điện thoại'
                              : device.online
                                  ? 'Trực tuyến'
                                  : 'Hoạt động ${AppDates.ago(device.lastSeenAt)}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (battery != null)
                    StatusChip(
                      label: '$battery%',
                      icon: battery <= 15 ? Icons.battery_alert : Icons.battery_std,
                      color: battery <= 15 ? AppColors.danger : AppColors.success,
                    ),
                ],
              ),
              AppSpacing.gapMd,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(label: child.placeName, icon: placeIcon, color: placeColor),
                  if (child.lastLocation?.at != null)
                    StatusChip(label: 'cập nhật ${AppDates.ago(child.lastLocation!.at)}', icon: Icons.update, color: AppColors.offline),
                ],
              ),
              if (child.latestAlertTitle != null) ...[
                AppSpacing.gapSm,
                Row(
                  children: [
                    Icon(Icons.notifications_active, size: 16, color: AppColors.forLevel(child.latestAlertLevel ?? 'info')),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${child.latestAlertTitle} · ${AppDates.ago(child.latestAlertAt)}',
                          style: text.bodySmall, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
