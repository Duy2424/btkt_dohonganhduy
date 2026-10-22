// Luật kiểm tra (zod) cho ticket hỗ trợ: tạo, đổi trạng thái, nhắn tin, lọc danh sách.
import { z } from 'zod';
import { objectId, pagination } from '../common.schema.js';

export const STATUS_ORDER = ['open', 'in_progress', 'resolved', 'closed'];

export const listQuery = pagination.extend({
  status: z.enum(STATUS_ORDER).optional(),
  // Chỉ dùng cho nhân viên: hàng chờ / của tôi / đã xong
  scope: z.enum(['queue', 'mine', 'done', 'all']).optional().default('all'),
});

export const createTicketSchema = z.object({
  subject: z.string({ error: 'Vui lòng nhập tiêu đề' }).trim().min(5, 'Tiêu đề tối thiểu 5 ký tự').max(100, 'Tiêu đề tối đa 100 ký tự'),
  category: z.enum(['account', 'device', 'bug', 'other'], { error: 'Loại ticket không hợp lệ' }),
  content: z.string({ error: 'Vui lòng nhập nội dung' }).trim().min(10, 'Nội dung tối thiểu 10 ký tự').max(2000, 'Nội dung tối đa 2000 ký tự'),
});

export const updateTicketSchema = z.object({
  status: z.enum(STATUS_ORDER, { error: 'Trạng thái không hợp lệ' }),
});

export const messageSchema = z.object({
  content: z.string({ error: 'Vui lòng nhập nội dung' }).trim().min(1, 'Vui lòng nhập nội dung').max(2000, 'Tối đa 2000 ký tự'),
});

export const idParams = z.object({ id: objectId });
