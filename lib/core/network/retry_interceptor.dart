// Tự thử lại request khi server tạm mất (502/503/504, timeout, mất mạng), chờ tăng dần 1s, 2s, 4s.
// Chỉ thử lại request an toàn (GET) hoặc request được đánh dấu extra['retry'] = true.
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 3});

  final Dio _dio;
  final int maxRetries;

  bool _shouldRetry(DioException e) {
    final status = e.response?.statusCode;
    final transient = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        status == 502 ||
        status == 503 ||
        status == 504;
    final safe = e.requestOptions.method == 'GET' || e.requestOptions.extra['retry'] == true;
    return transient && safe;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['attempt'] as int?) ?? 0;
    if (!_shouldRetry(err) || attempt >= maxRetries) return handler.next(err);

    await Future<void>.delayed(Duration(seconds: 1 << attempt));
    final options = err.requestOptions..extra['attempt'] = attempt + 1;
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
