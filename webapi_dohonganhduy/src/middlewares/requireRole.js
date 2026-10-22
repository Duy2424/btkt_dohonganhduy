// Chặn theo vai trò ở server, vd requireRole('admin'), requireRole('staff', 'admin').
// App có chặn thì cũng chỉ để giao diện gọn, lớp bảo vệ thật nằm ở đây.
import { ApiError } from '../utils/ApiError.js';

export function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.auth) return next(ApiError.unauthorized());
    if (!roles.includes(req.auth.role)) return next(ApiError.forbidden());
    next();
  };
}
