// Gom mọi lỗi gọi API về ApiException với câu tiếng Việt dễ hiểu (map từ mã lỗi server / lỗi mạng).
// Màn hình chỉ cần hiển thị e.message, hoặc e.fieldErrors để báo lỗi đúng ô nhập.
import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.code, this.message, {this.statusCode, this.fieldErrors = const {}, this.details});

  final String code;
  final String message;
  final int? statusCode;

  /// Lỗi theo từng ô nhập: { 'email': 'Email đã được sử dụng' }
  final Map<String, String> fieldErrors;
  final dynamic details;

  bool get isNetwork => code == 'NETWORK_ERROR' || code == 'TIMEOUT';
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;

  /// Câu thay thế cho một số mã lỗi (server đã trả tiếng Việt, đây là phần dự phòng / làm rõ thêm).
  static const _friendly = <String, String>{
    'ROUTE_NOT_FOUND': 'Chức năng chưa có trên server, hãy cập nhật server',
    'INTERNAL_ERROR': 'Máy chủ gặp lỗi, vui lòng thử lại sau',
    'RATE_LIMITED': 'Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút',
    'TOKEN_EXPIRED': 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
  };

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final code = (err['code'] ?? 'ERROR').toString();
      final fields = <String, String>{};
      final details = err['details'];
      if (details is List) {
        for (final d in details) {
          if (d is Map && d['field'] != null && d['message'] != null) {
            fields.putIfAbsent(d['field'].toString(), () => d['message'].toString());
          }
        }
      }
      return ApiException(
        code,
        _friendly[code] ?? (err['message'] ?? 'Đã có lỗi xảy ra').toString(),
        statusCode: status,
        fieldErrors: fields,
        details: details,
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException('TIMEOUT', 'Máy chủ phản hồi quá lâu, kiểm tra mạng rồi thử lại', statusCode: status);
      case DioExceptionType.connectionError:
        return ApiException('NETWORK_ERROR', 'Không kết nối được máy chủ. Kiểm tra Internet hoặc server có đang chạy', statusCode: status);
      default:
        if (status == 502 || status == 503 || status == 504) {
          return ApiException('SERVER_DOWN', 'Máy chủ tạm thời không truy cập được, thử lại sau ít phút', statusCode: status);
        }
        return ApiException('UNKNOWN', 'Đã có lỗi xảy ra (${status ?? e.type.name})', statusCode: status);
    }
  }

  /// Bọc lỗi bất kỳ thành ApiException.
  static ApiException from(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      if (e.error is ApiException) return e.error as ApiException;
      return ApiException.fromDio(e);
    }
    return ApiException('UNKNOWN', 'Đã có lỗi xảy ra: $e');
  }
}
