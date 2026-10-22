// Các luật zod dùng chung cho nhiều module: ObjectId, phân trang, giờ "HH:mm", ngày trong tuần.
import { z } from 'zod';

export const objectId = z.string().regex(/^[a-f\d]{24}$/i, 'Mã định danh không hợp lệ');

export const pagination = z.object({
  page: z.coerce.number().int().min(1).optional().default(1),
  limit: z.coerce.number().int().min(1).max(100).optional().default(20),
  search: z.string().trim().max(100).optional().default(''),
});

export const timeHHmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Giờ phải có dạng HH:mm');

export const daysOfWeek = z
  .array(z.number().int().min(1).max(7))
  .min(1, 'Chọn ít nhất 1 ngày trong tuần')
  .transform((days) => [...new Set(days)].sort());

export const dateKey = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Ngày phải có dạng YYYY-MM-DD');

/** Escape chuỗi tìm kiếm trước khi đưa vào RegExp (tránh lỗi/ReDoS). */
export function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
