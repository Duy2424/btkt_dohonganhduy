// Controller xác thực: lấy dữ liệu đã kiểm tra, gọi auth.service, trả response chuẩn.
import { ok } from '../../utils/asyncHandler.js';
import * as authService from './auth.service.js';

export async function register(req, res) {
  const data = await authService.register(req.valid.body);
  ok(res, data, 'Đã gửi mã xác minh tới email của bạn', 201);
}

export async function verifyEmail(req, res) {
  ok(res, await authService.verifyEmail(req.valid.body), 'Xác minh email thành công');
}

export async function resendOtp(req, res) {
  ok(res, await authService.resendOtp(req.valid.body), 'Đã gửi lại mã OTP');
}

export async function login(req, res) {
  ok(res, await authService.login(req.valid.body), 'Đã gửi mã OTP tới email');
}

export async function verifyLoginOtp(req, res) {
  ok(res, await authService.verifyLoginOtp(req.valid.body), 'Đăng nhập thành công');
}

export async function faceLogin(req, res) {
  ok(res, await authService.faceLogin(req.valid.body), 'Đăng nhập bằng khuôn mặt thành công');
}

export async function refresh(req, res) {
  ok(res, await authService.refresh(req.valid.body));
}

export async function logout(req, res) {
  await authService.logout(req.valid.body);
  ok(res, null, 'Đã đăng xuất');
}

export async function forgotPassword(req, res) {
  ok(res, await authService.forgotPassword(req.valid.body), 'Nếu email tồn tại, mã OTP đã được gửi');
}

export async function resetPassword(req, res) {
  await authService.resetPassword(req.valid.body);
  ok(res, null, 'Đặt lại mật khẩu thành công, hãy đăng nhập lại');
}

export async function me(req, res) {
  ok(res, await authService.me(req.auth.userId));
}
