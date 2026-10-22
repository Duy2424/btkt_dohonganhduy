// Wrapper Dart cho MethodChannel "conan/native", gọi code Kotlin trong android/.../native/:
// kiểm tra/mở quyền, lấy danh sách app, bật/tắt dịch vụ khoá máy theo lịch.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LaunchableApp {
  const LaunchableApp(this.packageName, this.label);
  final String packageName;
  final String label;
  Map<String, String> toJson() => {'packageName': packageName, 'label': label};
}

class NativeChannel {
  NativeChannel._();
  static const _channel = MethodChannel('conan/native');

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('Native $method lỗi: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> hasUsageAccess() async => await _call<bool>('hasUsageAccess') ?? false;
  static Future<void> openUsageAccessSettings() => _call('openUsageAccessSettings');
  static Future<bool> canDrawOverlays() async => await _call<bool>('canDrawOverlays') ?? false;
  static Future<void> openOverlaySettings() => _call('openOverlaySettings');
  static Future<void> openAppDetailsSettings() => _call('openAppDetailsSettings');

  /// Mở trang cài đặt riêng của MIUI/HyperOS (autostart, popup nền, pin). Trả false nếu không mở được.
  static Future<bool> openXiaomiSettings(String page) async => await _call<bool>('openXiaomiSettings', page) ?? false;

  static Future<List<LaunchableApp>> getLaunchableApps() async {
    final list = await _call<List<dynamic>>('getLaunchableApps') ?? const [];
    return list
        .map((e) => LaunchableApp((e as Map)['packageName'] as String, (e['label'] ?? '') as String))
        .toList();
  }

  static Future<void> startLockService(Map<String, dynamic> config) => _call('startLockService', jsonEncode(config));
  static Future<void> updateLockConfig(Map<String, dynamic> config) => _call('updateLockConfig', jsonEncode(config));
  static Future<void> stopLockService() => _call('stopLockService');
}
