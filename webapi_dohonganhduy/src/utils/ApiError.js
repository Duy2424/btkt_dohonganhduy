// Lỗi nghiệp vụ có mã HTTP và mã lỗi để máy đọc. errorHandler đổi nó thành JSON chuẩn
// { success: false, error: { code, message, details? } }.
export class ApiError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static badRequest(code, message, details) {
    return new ApiError(400, code, message, details);
  }

  static unauthorized(code = 'UNAUTHORIZED', message = 'Bạn cần đăng nhập') {
    return new ApiError(401, code, message);
  }

  static forbidden(code = 'FORBIDDEN', message = 'Bạn không có quyền thực hiện thao tác này') {
    return new ApiError(403, code, message);
  }

  static notFound(message = 'Không tìm thấy dữ liệu') {
    return new ApiError(404, 'NOT_FOUND', message);
  }

  static conflict(code, message, details) {
    return new ApiError(409, code, message, details);
  }

  static tooMany(code, message, details) {
    return new ApiError(429, code, message, details);
  }
}
