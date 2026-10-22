// Luật kiểm tra dữ liệu (zod) cho đăng ký / đăng nhập / OTP / quên mật khẩu.
// Bên app, lib/core/utils/validators.dart dùng đúng các luật này.
import { z } from 'zod';

export const usernameField = z
  .string({ error: 'Vui lòng nhập tên đăng nhập' })
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9_]{3,20}$/, 'Tên đăng nhập 3–20 ký tự, chỉ gồm chữ thường, số và dấu _');

export const passwordField = z
  .string({ error: 'Vui lòng nhập mật khẩu' })
  .min(8, 'Mật khẩu tối thiểu 8 ký tự')
  .max(72, 'Mật khẩu tối đa 72 ký tự')
  .regex(/[A-Za-z]/, 'Mật khẩu phải có chữ cái')
  .regex(/\d/, 'Mật khẩu phải có chữ số');

export const emailField = z
  .string({ error: 'Vui lòng nhập email' })
  .trim()
  .toLowerCase()
  .pipe(z.email('Email không hợp lệ'));

export const fullNameField = z
  .string({ error: 'Vui lòng nhập họ tên' })
  .trim()
  .min(2, 'Họ tên tối thiểu 2 ký tự')
  .max(60, 'Họ tên tối đa 60 ký tự');

export const phoneField = z
  .string()
  .trim()
  .regex(/^(\+?\d{9,12})?$/, 'Số điện thoại không hợp lệ')
  .optional()
  .default('');

const otpCode = z.string({ error: 'Vui lòng nhập mã OTP' }).regex(/^\d{6}$/, 'Mã OTP gồm 6 chữ số');
const sessionId = z.string({ error: 'Thiếu phiên OTP' }).min(1, 'Thiếu phiên OTP');

export const registerSchema = z.object({
  fullName: fullNameField,
  username: usernameField,
  email: emailField,
  password: passwordField,
  phone: phoneField,
});

export const verifyOtpSchema = z.object({ otpSessionId: sessionId, code: otpCode });

export const resendOtpSchema = z.union([
  z.object({ otpSessionId: sessionId }),
  z.object({ email: emailField, purpose: z.literal('verify_email') }),
]);

export const loginSchema = z.object({
  username: usernameField,
  password: z.string({ error: 'Vui lòng nhập mật khẩu' }).min(1, 'Vui lòng nhập mật khẩu'),
  deviceId: z.string().max(100).optional().default(''),
  deviceName: z.string().max(100).optional().default(''),
});

export const refreshSchema = z.object({
  refreshToken: z.string({ error: 'Thiếu refresh token' }).min(1, 'Thiếu refresh token'),
});

export const faceLoginSchema = z.object({
  deviceId: z.string({ error: 'Thiếu mã thiết bị' }).min(1, 'Thiếu mã thiết bị'),
  refreshToken: z.string({ error: 'Thiếu token khuôn mặt' }).min(1, 'Thiếu token khuôn mặt'),
});

export const forgotPasswordSchema = z.object({ email: emailField });

export const resetPasswordSchema = z.object({
  otpSessionId: sessionId,
  code: otpCode,
  newPassword: passwordField,
});
