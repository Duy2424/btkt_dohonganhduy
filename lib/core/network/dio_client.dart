// Tạo Dio dùng chung (base URL từ Env, timeout, interceptor JWT/refresh + retry) và ApiClient
// bóc lớp { success, data } của server, đổi mọi lỗi thành ApiException tiếng Việt.
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

BaseOptions _options() => BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    );

Dio createDio() {
  final dio = Dio(_options());
  final refreshDio = Dio(_options());
  final auth = AuthInterceptor(dio, refreshDio);
  dio.interceptors.addAll([auth, RetryInterceptor(dio)]);
  // Bản debug: in request/lỗi ra log (adb logcat -s flutter) để nhóm dò lỗi khi chạy thử trên máy
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestHeader: false, responseHeader: false, logPrint: (o) => debugPrint('[API] $o')));
  }
  return dio;
}

final dioProvider = Provider<Dio>((ref) => createDio());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));

class ApiClient {
  ApiClient(this.dio);
  final Dio dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? data, bool auth = true, bool retry = false}) => _wrap(
        () => dio.post<dynamic>(path, data: data, options: Options(extra: {'auth': auth, 'retry': retry})),
      );

  Future<dynamic> patch(String path, {Object? data}) => _wrap(() => dio.patch<dynamic>(path, data: data));

  Future<dynamic> delete(String path, {Object? data}) => _wrap(() => dio.delete<dynamic>(path, data: data));

  /// Gọi API không qua /api (vd /health).
  Future<Map<String, dynamic>> raw(String path) async {
    try {
      final res = await dio.get<dynamic>(path, options: Options(extra: {'auth': false}));
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) =>
      q == null ? null : (Map.of(q)..removeWhere((_, v) => v == null || v == ''));

  Future<dynamic> _wrap(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final body = res.data;
      return body is Map ? body['data'] : body;
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}
