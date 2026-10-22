// Luật kiểm tra (zod) cho buổi học: nhiều thứ, giờ vào < giờ ra (trong ngày), gắn vùng "Trường".
import { z } from 'zod';
import { daysOfWeek, objectId, timeHHmm } from '../common.schema.js';

const fields = {
  geofenceId: objectId,
  daysOfWeek,
  startTime: timeHHmm,
  endTime: timeHHmm,
  label: z.string().trim().max(30, 'Nhãn tối đa 30 ký tự').optional().default(''),
  graceMinutes: z.number().int().min(0).max(120).optional().default(15),
  outsideToleranceMinutes: z.number().int().min(1).max(60).optional().default(5),
  active: z.boolean().optional().default(true),
};

const startBeforeEnd = (v) => !v.startTime || !v.endTime || v.startTime < v.endTime;
const orderMessage = { message: 'Giờ vào học phải trước giờ tan học', path: ['endTime'] };

export const createSessionSchema = z.object({ childId: objectId, ...fields }).refine(startBeforeEnd, orderMessage);

export const updateSessionSchema = z
  .object({
    geofenceId: objectId.optional(),
    daysOfWeek: daysOfWeek.optional(),
    startTime: timeHHmm.optional(),
    endTime: timeHHmm.optional(),
    label: z.string().trim().max(30).optional(),
    graceMinutes: z.number().int().min(0).max(120).optional(),
    outsideToleranceMinutes: z.number().int().min(1).max(60).optional(),
    active: z.boolean().optional(),
  })
  .refine(startBeforeEnd, orderMessage);

export const listQuery = z.object({ childId: objectId });
export const idParams = z.object({ id: objectId });
