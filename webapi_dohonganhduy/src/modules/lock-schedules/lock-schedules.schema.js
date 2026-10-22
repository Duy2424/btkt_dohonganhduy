// Luật kiểm tra (zod) cho lịch khoá máy: cho phép qua nửa đêm (vd 21:30–06:30), giờ bắt đầu ≠ giờ kết thúc.
import { z } from 'zod';
import { daysOfWeek, objectId, timeHHmm } from '../common.schema.js';

const packageName = z.string().trim().regex(/^[a-zA-Z][\w]*(\.[\w]+)+$/, 'Tên gói ứng dụng không hợp lệ');
const notSame = (v) => !v.startTime || !v.endTime || v.startTime !== v.endTime;
const notSameMessage = { message: 'Giờ bắt đầu và kết thúc không được trùng nhau', path: ['endTime'] };

export const createLockSchema = z
  .object({
    childId: objectId,
    name: z.string({ error: 'Vui lòng nhập tên lịch' }).trim().min(1, 'Vui lòng nhập tên lịch').max(40, 'Tên lịch tối đa 40 ký tự'),
    daysOfWeek,
    startTime: timeHHmm,
    endTime: timeHHmm,
    allowedPackages: z.array(packageName).max(50).optional().default([]),
    enabled: z.boolean().optional().default(true),
  })
  .refine(notSame, notSameMessage);

export const updateLockSchema = z
  .object({
    name: z.string().trim().min(1, 'Vui lòng nhập tên lịch').max(40).optional(),
    daysOfWeek: daysOfWeek.optional(),
    startTime: timeHHmm.optional(),
    endTime: timeHHmm.optional(),
    allowedPackages: z.array(packageName).max(50).optional(),
    enabled: z.boolean().optional(),
  })
  .refine(notSame, notSameMessage);

export const listQuery = z.object({ childId: objectId });
export const idParams = z.object({ id: objectId });
