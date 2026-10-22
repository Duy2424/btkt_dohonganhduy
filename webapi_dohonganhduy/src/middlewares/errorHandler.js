// Xử lý lỗi tập trung. Mọi lỗi trả về { success: false, error: { code, message, details? } }.
import mongoose from 'mongoose';
import { ApiError } from '../utils/ApiError.js';
import { logger } from '../utils/logger.js';

export function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    error: { code: 'ROUTE_NOT_FOUND', message: `Không có đường dẫn ${req.method} ${req.path}` },
  });
}

export function errorHandler(err, req, res, next) {
  if (err instanceof ApiError) {
    const error = { code: err.code, message: err.message };
    if (err.details !== undefined) error.details = err.details;
    return res.status(err.status).json({ success: false, error });
  }
  if (err instanceof mongoose.Error.CastError) {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_ID', message: 'Mã định danh không hợp lệ' },
    });
  }
  if (err?.code === 11000) {
    return res.status(409).json({
      success: false,
      error: { code: 'DUPLICATE', message: 'Dữ liệu đã tồn tại', details: err.keyValue },
    });
  }
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_JSON', message: 'Dữ liệu gửi lên không phải JSON hợp lệ' },
    });
  }
  logger.error(err);
  return res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'Lỗi máy chủ, vui lòng thử lại sau' },
  });
}
