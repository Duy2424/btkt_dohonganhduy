// Luật kiểm tra (zod) cho vùng an toàn: tâm (lat/lng), bán kính 50–1000 m, loại home/school/other.
import { z } from 'zod';
import { objectId } from '../common.schema.js';

const base = {
  name: z.string({ error: 'Vui lòng nhập tên vùng' }).trim().min(1, 'Vui lòng nhập tên vùng').max(50, 'Tên vùng tối đa 50 ký tự'),
  type: z.enum(['home', 'school', 'other'], { error: 'Loại vùng không hợp lệ' }),
  center: z.object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
  }, { error: 'Vui lòng chọn vị trí trên bản đồ' }),
  radiusM: z
    .number({ error: 'Bán kính không hợp lệ' })
    .min(50, 'Bán kính tối thiểu 50 m')
    .max(1000, 'Bán kính tối đa 1000 m'),
  notifyEnter: z.boolean().optional().default(true),
  notifyExit: z.boolean().optional().default(true),
  active: z.boolean().optional().default(true),
};

export const createGeofenceSchema = z.object({ childId: objectId, ...base });

export const updateGeofenceSchema = z.object({
  name: base.name.optional(),
  type: base.type.optional(),
  center: base.center.optional(),
  radiusM: base.radiusM.optional(),
  notifyEnter: z.boolean().optional(),
  notifyExit: z.boolean().optional(),
  active: z.boolean().optional(),
});

export const listQuery = z.object({ childId: objectId });
export const idParams = z.object({ id: objectId });
