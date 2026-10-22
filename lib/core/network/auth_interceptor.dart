// Gắn token vào mọi request và tự làm mới access token (15 phút) bằng refresh token khi nhận 401 TOKEN_EXPIRED.
// Nhiều request cùng hết hạn thì chỉ gọi /auth/refresh một lần (dùng Completer), các request khác chờ rồi gửi lại.
import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/local_prefs.dart';
import '../storage/secure_storage.dart';
import 'auth_events.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._dio, this._refreshDio);

  final Dio _dio;
  final Dio _refreshDio; // Dio riêng, không có interceptor → tránh vòng lặp khi refresh
  Completer<String?>? _refreshing;

  final _store = SecureStore.instance;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['auth'] != false) {
      final isChild = LocalPrefs.instance.mode == AppMode.child;
      final token = await _store.read(isChild ? SecureStore.kDeviceToken : SecureStore.kAccess);
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final code = response?.data is Map ? (response!.data['error']?['code'] as String?) : null;
    if (response?.statusCode != 401 || err.requestOptions.extra['auth'] == false) {
      return handler.next(err);
    }

    // Máy con bị huỷ ghép → quay về màn hình quét QR
    if (code == 'DEVICE_UNPAIRED') {
      AuthEvents.emit(AuthEvent.deviceUnpaired);
      return handler.next(err);
    }

    if (code != 'TOKEN_EXPIRED' || err.requestOptions.extra['retried'] == true) {
      if (code == 'TOKEN_INVALID') AuthEvents.emit(AuthEvent.sessionExpired);
      return handler.next(err);
    }

    final newToken = await refreshAccessToken();
    if (newToken == null) {
      AuthEvents.emit(AuthEvent.sessionExpired);
      return handler.next(err);
    }
    final options = err.requestOptions
      ..headers['Authorization'] = 'Bearer $newToken'
      ..extra['retried'] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Gọi /auth/refresh (xoay vòng refresh token). Trả về access token mới hoặc null nếu phiên đã hết.
  Future<String?> refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = _refreshing = Completer<String?>();
    try {
      final refresh = await _store.read(SecureStore.kRefresh);
      if (refresh == null) {
        completer.complete(null);
      } else {
        final res = await _refreshDio.post<dynamic>('/api/auth/refresh', data: {'refreshToken': refresh});
        final data = res.data['data'] as Map;
        await _store.saveSession(data['accessToken'] as String, data['refreshToken'] as String);
        completer.complete(data['accessToken'] as String);
      }
    } on DioException catch (e) {
      // Chỉ xoá phiên khi server từ chối refresh token (401); lỗi mạng thì giữ để thử lại sau
      if (e.response?.statusCode == 401) await _store.clearSession();
      completer.complete(null);
    } finally {
      _refreshing = null;
    }
    return completer.future;
  }
}
