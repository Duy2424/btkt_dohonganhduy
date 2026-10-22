// Luật kiểm tra (zod) cho thiết bị: ghép QR, gửi vị trí (gộp), danh sách app, SOS, trạng thái quyền.
import { z } from 'zod';
import { objectId } from '../common.schema.js';

export const pairSchema = z.object({
  code: z.string({ error: 'Thiếu mã ghép' }).min(20, 'Mã QR không hợp lệ').max(100, 'Mã QR không hợp lệ'),
  model: z.string().max(100).optional().default(''),
  androidVersion: z.string().max(20).optional().default(''),
  appVersion: z.string().max(20).optional().default(''),
});

const point = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracy: z.number().min(0).nullable().optional(),
  speed: z.number().nullable().optional(),
  battery: z.number().int().min(0).max(100).nullable().optional(),
  recordedAt: z.coerce.date(),
});

export const locationsSchema = z.object({
  points: z.array(point).min(1, 'Không có điểm vị trí nào').max(500, 'Tối đa 500 điểm mỗi lần gửi'),
});

export const appsSchema = z.object({
  apps: z
    .array(z.object({ packageName: z.string().min(1).max(200), label: z.string().max(200).optional().default('') }))
    .max(1000),
});

export const sosSchema = z.object({
  lat: z.number().min(-90).max(90).nullable().optional(),
  lng: z.number().min(-180).max(180).nullable().optional(),
  accuracy: z.number().min(0).nullable().optional(),
});

export const fcmTokenSchema = z.object({ token: z.string().min(10, 'FCM token không hợp lệ') });

export const permissionSchema = z.object({
  permissions: z.record(z.string(), z.boolean()),
});

export const leaveSchema = z.object({
  password: z.string({ error: 'Vui lòng nhập mật khẩu của bố mẹ' }).min(1, 'Vui lòng nhập mật khẩu của bố mẹ'),
});

export const renameSchema = z.object({
  name: z.string({ error: 'Vui lòng nhập tên thiết bị' }).trim().min(1, 'Vui lòng nhập tên thiết bị').max(40, 'Tên tối đa 40 ký tự'),
});

export const idParams = z.object({ id: objectId });
