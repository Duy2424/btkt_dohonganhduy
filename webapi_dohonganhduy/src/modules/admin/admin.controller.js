// Controller /api/admin/*: CRUD người dùng và thống kê.
import { ok } from '../../utils/asyncHandler.js';
import * as service from './admin.service.js';

export async function listUsers(req, res) {
  ok(res, await service.listUsers(req.valid.query));
}

export async function getUser(req, res) {
  ok(res, await service.getUser(req.valid.params.id));
}

export async function createUser(req, res) {
  ok(res, await service.createUser(req.valid.body), 'Đã tạo người dùng', 201);
}

export async function updateUser(req, res) {
  ok(res, await service.updateUser(req.auth.userId, req.valid.params.id, req.valid.body), 'Đã cập nhật người dùng');
}

export async function setStatus(req, res) {
  const user = await service.setStatus(req.auth.userId, req.valid.params.id, req.valid.body.status);
  ok(res, user, user.status === 'locked' ? 'Đã khoá tài khoản' : 'Đã mở khoá tài khoản');
}

export async function deleteUser(req, res) {
  await service.deleteUser(req.auth.userId, req.valid.params.id);
  ok(res, null, 'Đã xoá người dùng');
}

export async function stats(req, res) {
  ok(res, await service.stats());
}
