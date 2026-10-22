// Controller /api/geofences: vùng an toàn của con.
import { ok } from '../../utils/asyncHandler.js';
import * as service from './geofences.service.js';

export async function list(req, res) {
  ok(res, await service.list(req.auth.userId, req.valid.query.childId));
}

export async function create(req, res) {
  ok(res, await service.create(req.auth.userId, req.valid.body), 'Đã tạo vùng an toàn', 201);
}

export async function update(req, res) {
  ok(res, await service.update(req.auth.userId, req.valid.params.id, req.valid.body), 'Đã cập nhật vùng an toàn');
}

export async function remove(req, res) {
  await service.remove(req.auth.userId, req.valid.params.id);
  ok(res, null, 'Đã xoá vùng an toàn');
}
