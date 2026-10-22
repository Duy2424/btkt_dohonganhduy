// Đọc trạng thái các quyền của máy con và báo lên server (quyền bị tắt → server cảnh báo phụ huynh).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/platform/native_channel.dart';
import '../data/child_device_api.dart';

class PermissionStatusReader {
  PermissionStatusReader._();

  static Future<Map<String, bool>> read() async => {
        'location': await Permission.location.isGranted,
        'locationAlways': await Permission.locationAlways.isGranted,
        'notification': await Permission.notification.isGranted,
        'usageAccess': await NativeChannel.hasUsageAccess(),
        'overlay': await NativeChannel.canDrawOverlays(),
        'batteryOptimization': await Permission.ignoreBatteryOptimizations.isGranted,
      };

  static Future<Map<String, bool>> report(WidgetRef ref) async {
    final status = await read();
    try {
      await ref.read(childDeviceApiProvider).reportPermissions(status);
    } catch (_) {}
    return status;
  }
}
