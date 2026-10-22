// Controller /api/users/me/*: tài khoản của người đang đăng nhập.
import { ok } from '../../utils/asyncHandler.js';
import * as service from './users.service.js';

export async function updateMe(req, res) {
  ok(res, await service.updateMe(req.auth.userId, req.valid.body), 'Đã cập nhật thông tin');
}

export async function changePassword(req, res) {
  await service.changePassword(req.auth.userId, req.valid.body);
  ok(res, null, 'Đổi mật khẩu thành công');
}

export async function setFaceLogin(req, res) {
  const data = await service.setFaceLogin(req.auth.userId, req.valid.body);
  ok(res, data, data.faceLoginEnabled ? 'Đã bật đăng nhập khuôn mặt' : 'Đã tắt đăng nhập khuôn mặt');
}

export async function setFcmToken(req, res) {
  await service.setFcmToken(req.auth.userId, req.valid.body);
  ok(res, null);
}
