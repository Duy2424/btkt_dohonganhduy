// Thông báo cục bộ (flutter_local_notifications): tạo kênh thường / ưu tiên cao (cảnh báo đỏ) / kênh dịch vụ vị trí
// của máy con, và hiển thị cảnh báo nhận qua socket hoặc FCM khi app đang mở.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotification {
  LocalNotification._();

  static final plugin = FlutterLocalNotificationsPlugin();

  static const defaultChannel = AndroidNotificationChannel('conan_default', 'Cảnh báo ConAn',
      description: 'Cảnh báo thông thường về con', importance: Importance.defaultImportance);
  static const dangerChannel = AndroidNotificationChannel('conan_danger', 'Cảnh báo khẩn cấp',
      description: 'Rời trường trong giờ học, SOS…', importance: Importance.max);
  static const locationChannel = AndroidNotificationChannel('conan_location', 'Chia sẻ vị trí',
      description: 'Thông báo cố định khi máy con đang chia sẻ vị trí', importance: Importance.low);

  static Future<void> init() async {
    try {
      await plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final c in [defaultChannel, dangerChannel, locationChannel]) {
        await android?.createNotificationChannel(c);
      }
    } catch (e) {
      debugPrint('Không khởi tạo được thông báo: $e');
    }
  }

  static Future<void> requestPermission() async {
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> show({required String title, required String body, String level = 'info'}) async {
    final channel = level == 'danger' ? dangerChannel : defaultChannel;
    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: level == 'danger' ? Priority.max : Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }
}
