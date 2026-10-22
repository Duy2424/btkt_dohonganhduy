// Chức năng nâng cao "Chia sẻ vị trí", phía máy con: foreground service có thông báo cố định công khai,
// lấy vị trí bằng geolocator (lọc 25 m + nhịp tim 60 giây), gửi gộp qua REST kèm % pin.
// Mất mạng → xếp hàng trong bộ nhớ (tối đa 500 điểm), có mạng gửi bù. Bị huỷ ghép (401) → tự dừng.
import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/env.dart';
import '../../../core/storage/secure_storage.dart';

class LocationService {
  LocationService._();
  static final _service = FlutterBackgroundService();

  static Future<void> configure() async {
    try {
      // Mở lại app khi dịch vụ nền còn chạy, lệnh configure có lúc không trả về. Không chờ quá 3 giây,
      // nếu không main() đứng trước runApp và màn hình chỉ đen.
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onLocationServiceStart,
          autoStart: false,
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: 'conan_location',
          initialNotificationTitle: 'ConAn đang chia sẻ vị trí với bố mẹ',
          initialNotificationContent: 'Bố mẹ thấy được: vị trí, pin, lịch khoá máy',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Không cấu hình được dịch vụ nền: $e');
    }
  }

  static Future<bool> isRunning() => _service.isRunning();
  static Future<void> start() async {
    if (!await _service.isRunning()) await _service.startService();
  }

  static void stop() => _service.invoke('stop');
  static void locateNow() => _service.invoke('locate_now');
}

/// Chạy trong isolate riêng của foreground service (không có Riverpod / UI).
@pragma('vm:entry-point')
Future<void> onLocationServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final token = await SecureStore.instance.read(SecureStore.kDeviceToken);
  if (token == null) {
    service.stopSelf();
    return;
  }

  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Authorization': 'Bearer $token'},
  ));
  final battery = Battery();
  final queue = <Map<String, dynamic>>[]; // hàng đợi gửi bù khi mất mạng
  var sending = false;
  StreamSubscription<Position>? sub;
  Timer? heartbeat;

  void shutdown() {
    sub?.cancel();
    heartbeat?.cancel();
    service.stopSelf();
  }

  Future<void> flush() async {
    if (sending || queue.isEmpty) return;
    sending = true;
    try {
      while (queue.isNotEmpty) {
        final batch = queue.take(100).toList();
        await dio.post<dynamic>('/api/devices/me/locations', data: {'points': batch});
        queue.removeRange(0, batch.length);
      }
      service.invoke('sent', {'at': DateTime.now().toIso8601String(), 'pending': 0});
    } on DioException catch (e) {
      final body = e.response?.data;
      final err = body is Map ? body['error'] : null;
      final code = err is Map ? err['code'] : null;
      if (e.response?.statusCode == 401 && code == 'DEVICE_UNPAIRED') {
        service.invoke('unpaired');
        shutdown();
      } else {
        service.invoke('sent', {'pending': queue.length, 'error': true});
      }
    } finally {
      sending = false;
    }
  }

  DateTime? lastRecordedAt;

  Future<void> record(Position p) async {
    if (p.timestamp == lastRecordedAt) return; // luồng vị trí và lần lấy ngay có thể trả cùng 1 điểm
    lastRecordedAt = p.timestamp;
    int? level;
    try {
      level = await battery.batteryLevel;
    } catch (_) {}
    queue.add({
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'speed': p.speed,
      'battery': level,
      'recordedAt': p.timestamp.toUtc().toIso8601String(),
    });
    if (queue.length > 500) queue.removeAt(0);
    await flush();
  }

  Future<void> currentPosition() async {
    try {
      await record(await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      ));
    } catch (e) {
      debugPrint('Không lấy được vị trí: $e');
      await flush(); // vẫn thử gửi bù hàng đợi
    }
  }

  service.on('stop').listen((_) => shutdown());
  service.on('locate_now').listen((_) => currentPosition());

  sub = Geolocator.getPositionStream(
    locationSettings: AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
  ).listen(record, onError: (Object e) => debugPrint('Luồng vị trí lỗi: $e'));
  heartbeat = Timer.periodic(const Duration(seconds: 60), (_) => currentPosition());
  await currentPosition();
}
