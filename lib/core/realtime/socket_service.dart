// Kết nối Socket.IO cho máy phụ huynh: xác thực JWT trong handshake, tự reconnect, nhận vị trí / cảnh báo realtime.
// Socket rớt → tự gọi lại API mỗi 30 giây (fallback) để bản đồ vẫn cập nhật.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/alerts/state/alerts_providers.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/children/data/models/child_profile.dart';
import '../../features/children/state/children_providers.dart';
import '../../features/devices/data/devices_api.dart';
import '../config/env.dart';
import '../push/fcm_service.dart';
import '../push/local_notification.dart';
import '../storage/secure_storage.dart';

/// Tên event, trùng với webapi_dohonganhduy/src/sockets/events.js
class SocketEvents {
  static const locationNew = 'location:new';
  static const alertNew = 'alert:new';
  static const devicePaired = 'device:paired';
  static const deviceStatus = 'device:status';
}

/// true = socket đang kết nối. Màn phụ huynh watch provider này để giữ kết nối sống.
final realtimeProvider = NotifierProvider<RealtimeService, bool>(RealtimeService.new);

class RealtimeService extends Notifier<bool> {
  io.Socket? _socket;
  Timer? _fallback;
  final _paired = StreamController<Map<String, dynamic>>.broadcast();

  /// Màn QR lắng nghe để chuyển "Ghép thành công 🎉".
  Stream<Map<String, dynamic>> get devicePaired => _paired.stream;

  @override
  bool build() {
    ref.onDispose(() {
      _fallback?.cancel();
      _socket?.dispose();
      _paired.close();
    });
    _connect();
    _registerPush();
    return false;
  }

  Future<void> _registerPush() async {
    final token = await FcmService.token();
    if (token != null) {
      try {
        await ref.read(authApiProvider).setFcmToken(token);
      } catch (_) {}
    }
  }

  Future<void> _connect() async {
    final token = await SecureStore.instance.read(SecureStore.kAccess);
    final socket = _socket = io.io(
      Env.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      state = true;
      _fallback?.cancel();
      ref.read(childrenProvider.notifier).refresh();
    });
    socket.onDisconnect((_) => _onLost());
    socket.onConnectError((err) async {
      _onLost();
      // Access token hết hạn → gọi 1 API để interceptor tự refresh rồi dùng token mới
      if ('$err'.contains('TOKEN_EXPIRED') || '$err'.contains('UNAUTHORIZED')) {
        try {
          await ref.read(authApiProvider).me();
          socket.auth = {'token': await SecureStore.instance.read(SecureStore.kAccess)};
        } catch (_) {}
      }
    });

    socket.on(SocketEvents.locationNew, (data) {
      final m = Map<String, dynamic>.from(data as Map);
      ref.read(childrenProvider.notifier).applyLive(
            m['childId'] as String,
            GeoPoint.fromJson(m['lastLocation']),
            DeviceSummary.fromJson(m['device']),
          );
    });
    socket.on(SocketEvents.alertNew, (data) {
      final m = Map<String, dynamic>.from(data as Map);
      ref.invalidate(alertsProvider);
      ref.read(childrenProvider.notifier).refresh();
      // Chưa có FCM thì tự hiện thông báo từ socket
      if (!FcmService.available && m['silent'] != true) {
        LocalNotification.show(
          title: '${m['childName'] ?? ''}: ${m['title']}',
          body: (m['message'] ?? '') as String,
          level: (m['level'] ?? 'info') as String,
        );
      }
    });
    socket.on(SocketEvents.devicePaired, (data) {
      _paired.add(Map<String, dynamic>.from(data as Map));
      ref.read(childrenProvider.notifier).refresh();
      ref.invalidate(devicesProvider);
    });
    socket.on(SocketEvents.deviceStatus, (_) {
      ref.read(childrenProvider.notifier).refresh();
      ref.invalidate(devicesProvider);
    });
    socket.connect();
  }

  void _onLost() {
    state = false;
    _fallback ??= Timer.periodic(const Duration(seconds: 30), (_) {
      debugPrint('Socket rớt → tải lại vị trí bằng API');
      ref.read(childrenProvider.notifier).refresh();
    });
  }
}
