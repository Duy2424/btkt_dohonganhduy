// Controller cảnh báo của phụ huynh: danh sách (lọc con / loại / chưa đọc), đánh dấu đọc, xoá.
import { ok } from '../../utils/asyncHandler.js';
import * as service from './alerts.service.js';

export async function list(req, res) {
  ok(res, await service.list(req.auth.userId, req.valid.query));
}

export async function markRead(req, res) {
  ok(res, await service.markRead(req.auth.userId, req.valid.params.id));
}

export async function markAllRead(req, res) {
  ok(res, await service.markAllRead(req.auth.userId), 'Đã đánh dấu tất cả là đã đọc');
}

export async function remove(req, res) {
  await service.remove(req.auth.userId, req.valid.params.id);
  ok(res, null, 'Đã xoá cảnh báo');
}

export async function removeRead(req, res) {
  ok(res, await service.removeRead(req.auth.userId), 'Đã xoá các cảnh báo đã đọc');
}
