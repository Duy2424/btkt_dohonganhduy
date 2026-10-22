// Controller /api/lock-schedules: lịch khoá máy của con.
import { ok } from '../../utils/asyncHandler.js';
import * as service from './lock-schedules.service.js';

export async function list(req, res) {
  ok(res, await service.list(req.auth.userId, req.valid.query.childId));
}

export async function create(req, res) {
  ok(res, await service.create(req.auth.userId, req.valid.body), 'Đã tạo lịch khoá', 201);
}

export async function update(req, res) {
  ok(res, await service.update(req.auth.userId, req.valid.params.id, req.valid.body), 'Đã cập nhật lịch khoá');
}

export async function remove(req, res) {
  await service.remove(req.auth.userId, req.valid.params.id);
  ok(res, null, 'Đã xoá lịch khoá');
}
