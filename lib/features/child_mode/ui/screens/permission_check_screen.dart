// Màn "Kiểm tra quyền" của máy con: mỗi quyền một dòng ✓/✗ + nút mở đúng trang cài đặt.
// Riêng Xiaomi (MIUI/HyperOS): Tự khởi chạy, cửa sổ bật lên khi chạy nền, Tiết kiệm pin → "Không giới hạn".
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/platform/native_channel.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../services/location_service.dart';
import '../../services/permission_status.dart';

class PermissionCheckScreen extends ConsumerStatefulWidget {
  const PermissionCheckScreen({super.key});

  @override
  ConsumerState<PermissionCheckScreen> createState() => _PermissionCheckScreenState();
}

class _PermissionCheckScreenState extends ConsumerState<PermissionCheckScreen> with WidgetsBindingObserver {
  Map<String, bool> _status = {};
  bool _isXiaomi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeviceInfoPlugin().androidInfo.then((info) {
      final m = info.manufacturer.toLowerCase();
      if (mounted) setState(() => _isXiaomi = m.contains('xiaomi') || m.contains('redmi') || m.contains('poco'));
    });
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Quay lại từ trang Cài đặt → kiểm tra lại
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await PermissionStatusReader.read();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _requestLocation() async {
    await Permission.location.request();
    // Android 11+: "Luôn cho phép" phải bật trong trang cài đặt
    if (await Permission.location.isGranted) await Permission.locationAlways.request();
    _refresh();
  }

  /// Trang riêng của MIUI cũ không còn trên HyperOS (mở không lên, không báo lỗi) → luôn mở trang
  /// "Thông tin ứng dụng" (HyperOS có đủ Tự khởi chạy / Tiết kiệm pin / Quyền khác) kèm hướng dẫn chữ.
  Future<void> _xiaomi(String guide) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.phone_android, size: 36),
        title: const Text('Làm theo hướng dẫn'),
        content: Text(guide),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mở cài đặt'))],
      ),
    );
    await NativeChannel.openAppDetailsSettings();
  }

  Future<void> _done() async {
    if (_status['location'] != true) return showError(context, 'Cần cho phép vị trí để bố mẹ thấy con ở đâu');
    await LocationService.start();
    await PermissionStatusReader.report(ref);
    if (mounted) context.go('/child');
  }

  Widget _row(String key, String title, VoidCallback onFix) {
    final ok = _status[key] == true;
    return ListTile(
      leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? AppColors.success : AppColors.danger, size: 32),
      title: Text(title),
      trailing: ok ? null : FilledButton.tonal(onPressed: onFix, child: const Text('Mở')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra quyền')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Card(
              child: Column(children: [
                _row('location', 'Vị trí', _requestLocation),
                _row('locationAlways', 'Vị trí "Luôn cho phép"', () async {
                  await Permission.locationAlways.request();
                  if (!await Permission.locationAlways.isGranted) await openAppSettings();
                  _refresh();
                }),
                _row('notification', 'Thông báo', () async {
                  await Permission.notification.request();
                  _refresh();
                }),
                _row('usageAccess', 'Truy cập dữ liệu sử dụng', NativeChannel.openUsageAccessSettings),
                _row('overlay', 'Hiển thị trên ứng dụng khác', NativeChannel.openOverlaySettings),
                _row('batteryOptimization', 'Không giới hạn pin', () async {
                  await Permission.ignoreBatteryOptimizations.request();
                  _refresh();
                }),
              ]),
            ),
            if (_isXiaomi) ...[
              const SectionHeader('Riêng máy Xiaomi / Redmi / POCO'),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Tự khởi chạy (Autostart)'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _xiaomi('Trong trang vừa mở: bật "Tự khởi chạy" (Autostart) cho ConAn.'),
                      child: const Text('Mở'),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Hiển thị cửa sổ bật lên khi chạy trong nền'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _xiaomi('Trong trang vừa mở: vào "Quyền khác" (Other permissions) → cho phép "Hiển thị cửa sổ bật lên khi đang chạy trong nền".'),
                      child: const Text('Mở'),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.battery_saver),
                    title: const Text('Tiết kiệm pin → "Không giới hạn"'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _xiaomi('Trong trang vừa mở: vào "Tiết kiệm pin" (Battery saver) → chọn "Không giới hạn".'),
                      child: const Text('Mở'),
                    ),
                  ),
                ]),
              ),
            ],
            AppSpacing.gapLg,
            AppButton(label: 'Xong, bắt đầu chia sẻ vị trí', icon: Icons.check, onPressed: _done),
          ],
        ),
      ),
    );
  }
}
