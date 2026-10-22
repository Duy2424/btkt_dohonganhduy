// Điểm khởi động app ConAn: đọc cấu hình máy, khởi tạo thông báo + Firebase (nếu có) + dịch vụ nền của máy con,
// rồi chạy MaterialApp.router trong ProviderScope (Riverpod).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/push/fcm_service.dart';
import 'core/push/local_notification.dart';
import 'core/storage/local_prefs.dart';
import 'features/child_mode/services/location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await LocalPrefs.init();
  await initializeDateFormatting('vi');
  await LocalNotification.init();
  await FcmService.init();
  await LocationService.configure();
  runApp(
    // Tắt tự thử lại của Riverpod: lỗi hiện ngay màn "Thử lại" cho người dùng chủ động
    ProviderScope(retry: (_, _) => null, child: const ConAnApp()),
  );
}
