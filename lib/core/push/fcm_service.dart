// Firebase Cloud Messaging: máy phụ huynh nhận thông báo cảnh báo; máy con nhận data message
// "locate_now" (gửi vị trí ngay) và "config_changed" (tải lại lịch khoá).
// Chưa có android/app/google-services.json thì Firebase không khởi tạo được: bỏ qua push, app vẫn chạy nhờ socket.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'local_notification.dart';

/// Xử lý data message khi app đang ở nền (hàm top-level theo yêu cầu của firebase_messaging).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  _handleData(message.data);
}

void _handleData(Map<String, dynamic> data) {
  final type = data['type'];
  if (type == 'locate_now' || type == 'config_changed') {
    // Chuyển cho dịch vụ nền của máy con (child_mode/services/location_service.dart)
    FlutterBackgroundService().invoke(type as String);
  }
}

class FcmService {
  FcmService._();
  static bool available = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      FirebaseMessaging.onMessage.listen((m) {
        if (m.notification != null) {
          LocalNotification.show(
            title: m.notification!.title ?? 'ConAn',
            body: m.notification!.body ?? '',
            level: (m.data['level'] ?? 'info') as String,
          );
        }
        _handleData(m.data);
      });
      available = true;
    } catch (e) {
      debugPrint('Firebase chưa cấu hình (thiếu google-services.json) → bỏ qua push: $e');
    }
  }

  /// Lấy FCM token để gửi lên server (null nếu chưa cấu hình Firebase).
  static Future<String?> token() async {
    if (!available) return null;
    try {
      await FirebaseMessaging.instance.requestPermission();
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Không lấy được FCM token: $e');
      return null;
    }
  }
}
