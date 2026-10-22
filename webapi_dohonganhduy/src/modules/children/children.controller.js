// Controller hồ sơ con /api/children/* (chỉ phụ huynh).
import { ok } from '../../utils/asyncHandler.js';
import * as service from './children.service.js';

export async function list(req, res) {
  ok(res, await service.list(req.auth.userId, req.valid.query));
}

export async function get(req, res) {
  ok(res, await service.get(req.auth.userId, req.valid.params.id));
}

export async function create(req, res) {
  ok(res, await service.create(req.auth.userId, req.valid.body), 'Đã thêm hồ sơ con', 201);
}

export async function update(req, res) {
  ok(res, await service.update(req.auth.userId, req.valid.params.id, req.valid.body), 'Đã cập nhật hồ sơ');
}

export async function remove(req, res) {
  await service.remove(req.auth.userId, req.valid.params.id);
  ok(res, null, 'Đã xoá hồ sơ con và toàn bộ dữ liệu liên quan');
}

export async function createPairingCode(req, res) {
  ok(res, await service.createPairingCode(req.auth.userId, req.valid.params.id), 'Đã tạo mã ghép', 201);
}

export async function addOffDate(req, res) {
  ok(res, await service.addOffDate(req.auth.userId, req.valid.params.id, req.valid.body.date), 'Đã đánh dấu ngày nghỉ học');
}

export async function removeOffDate(req, res) {
  ok(res, await service.removeOffDate(req.auth.userId, req.valid.params.id, req.valid.body.date), 'Đã bỏ ngày nghỉ học');
}
