// Luật kiểm tra (zod) cho tài khoản của chính mình: sửa hồ sơ, đổi mật khẩu, bật/tắt khuôn mặt, FCM token.
import { z } from 'zod';
import { fullNameField, passwordField, phoneField } from '../auth/auth.schema.js';

export const updateMeSchema = z.object({
  fullName: fullNameField.optional(),
  phone: phoneField,
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'Vui lòng nhập mật khẩu hiện tại'),
  newPassword: passwordField,
});

export const faceLoginSchema = z.object({
  enabled: z.boolean(),
  deviceId: z.string().min(1, 'Thiếu mã thiết bị'),
  deviceName: z.string().max(100).optional().default(''),
  password: z.string().optional(),
});

export const fcmTokenSchema = z.object({ token: z.string().min(10, 'FCM token không hợp lệ') });
