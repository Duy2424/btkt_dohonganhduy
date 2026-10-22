// Middleware kiểm tra dữ liệu vào bằng zod. Kết quả đã chuẩn hoá đặt ở req.valid.{body,query,params}.
// Sai → 400 VALIDATION_ERROR, details = [{ field, message }] để app hiện lỗi đúng ô nhập.
import { ApiError } from '../utils/ApiError.js';

export function validate(schemas) {
  return (req, res, next) => {
    req.valid = req.valid || {};
    for (const part of ['params', 'query', 'body']) {
      if (!schemas[part]) continue;
      const result = schemas[part].safeParse(req[part] ?? {});
      if (!result.success) {
        const details = result.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        }));
        return next(
          ApiError.badRequest('VALIDATION_ERROR', details[0]?.message || 'Dữ liệu không hợp lệ', details),
        );
      }
      req.valid[part] = result.data;
    }
    next();
  };
}
