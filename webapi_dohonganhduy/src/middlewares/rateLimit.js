// Giới hạn số lần gọi các API nhạy cảm (đăng ký, đăng nhập, OTP, quên mật khẩu) để chống dò mật khẩu và spam mail.
import rateLimit from 'express-rate-limit';

const isTest = process.env.NODE_ENV === 'test';

function make(limit, windowMinutes) {
  return rateLimit({
    windowMs: windowMinutes * 60 * 1000,
    limit: isTest ? 10000 : limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler: (req, res) =>
      res.status(429).json({
        success: false,
        error: { code: 'RATE_LIMITED', message: 'Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút' },
      }),
  });
}

export const authLimiter = make(20, 15); // đăng ký / đăng nhập
export const otpLimiter = make(30, 15);
export const passwordLimiter = make(10, 15);
