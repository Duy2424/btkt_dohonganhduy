// Luật kiểm tra (zod) cho trang quản trị: CRUD người dùng, khoá/mở tài khoản.
import { z } from 'zod';
import { emailField, fullNameField, passwordField, phoneField, usernameField } from '../auth/auth.schema.js';
import { objectId, pagination } from '../common.schema.js';

const role = z.enum(['admin', 'staff', 'parent'], { error: 'Vai trò không hợp lệ' });

export const listUsersQuery = pagination.extend({
  role: role.optional(),
  status: z.enum(['pending', 'active', 'locked', 'deleted']).optional(),
});

export const createUserSchema = z.object({
  fullName: fullNameField,
  username: usernameField,
  email: emailField,
  password: passwordField,
  phone: phoneField,
  role,
});

export const updateUserSchema = z.object({
  fullName: fullNameField.optional(),
  email: emailField.optional(),
  phone: phoneField,
  role: role.optional(),
});

export const statusSchema = z.object({
  status: z.enum(['active', 'locked'], { error: 'Trạng thái chỉ được là active hoặc locked' }),
});

export const idParams = z.object({ id: objectId });
