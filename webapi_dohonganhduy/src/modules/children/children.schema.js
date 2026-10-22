// Luật kiểm tra (zod) cho hồ sơ con: tạo / sửa, ngày nghỉ học.
import { z } from 'zod';
import { dateKey, objectId } from '../common.schema.js';

const currentYear = new Date().getFullYear();

export const createChildSchema = z.object({
  name: z.string({ error: 'Vui lòng nhập tên con' }).trim().min(1, 'Vui lòng nhập tên con').max(40, 'Tên tối đa 40 ký tự'),
  birthYear: z
    .number({ error: 'Năm sinh không hợp lệ' })
    .int()
    .min(currentYear - 20, 'Năm sinh không hợp lệ')
    .max(currentYear, 'Năm sinh không hợp lệ')
    .nullable()
    .optional(),
  schoolName: z.string().trim().max(100, 'Tên trường tối đa 100 ký tự').optional().default(''),
  avatarColor: z
    .string()
    .regex(/^#[0-9A-Fa-f]{6}$/, 'Màu không hợp lệ')
    .optional()
    .default('#14B8A6'),
});

export const updateChildSchema = createChildSchema.partial().extend({
  schoolName: z.string().trim().max(100).optional(),
  avatarColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Màu không hợp lệ').optional(),
});

export const listChildrenQuery = z.object({ search: z.string().trim().max(50).optional().default('') });

export const offDateSchema = z.object({ date: dateKey });

export const idParams = z.object({ id: objectId });
