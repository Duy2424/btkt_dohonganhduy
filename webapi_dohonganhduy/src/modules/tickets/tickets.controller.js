// Controller /api/tickets/*, dùng chung cho phụ huynh, nhân viên, admin (service tự phân quyền).
import { ok } from '../../utils/asyncHandler.js';
import * as service from './tickets.service.js';

export async function list(req, res) {
  ok(res, await service.list(req.auth, req.valid.query));
}

export async function get(req, res) {
  ok(res, await service.get(req.auth, req.valid.params.id));
}

export async function create(req, res) {
  ok(res, await service.create(req.auth, req.valid.body), 'Đã gửi yêu cầu hỗ trợ', 201);
}

export async function claim(req, res) {
  ok(res, await service.claim(req.auth, req.valid.params.id), 'Đã nhận ticket');
}

export async function updateStatus(req, res) {
  ok(res, await service.updateStatus(req.auth, req.valid.params.id, req.valid.body.status), 'Đã cập nhật trạng thái');
}

export async function addMessage(req, res) {
  ok(res, await service.addMessage(req.auth, req.valid.params.id, req.valid.body.content), 'Đã gửi tin nhắn');
}

export async function remove(req, res) {
  await service.remove(req.auth, req.valid.params.id);
  ok(res, null, 'Đã xoá ticket');
}
