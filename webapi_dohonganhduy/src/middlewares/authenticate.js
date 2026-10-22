// Xác thực request: header "Authorization: Bearer <token>".
// - Token người dùng: JWT access token (15 phút) → req.auth = { userId, role }.
// - Token máy con: chuỗi "dev_…" cấp khi ghép QR → req.auth = { role: 'child', deviceId, childId, parentId }.
import { User } from '../models/User.js';
import { Device } from '../models/Device.js';
import { ApiError } from '../utils/ApiError.js';
import { DEVICE_TOKEN_PREFIX, hashToken, verifyAccessToken } from '../services/token.service.js';

export async function resolveAuth(token) {
  if (!token) throw ApiError.unauthorized();

  if (token.startsWith(DEVICE_TOKEN_PREFIX)) {
    const hash = hashToken(token);
    const device = await Device.findOne({ $or: [{ tokenHash: hash }, { simTokenHash: hash }] }).select(
      'childId parentId status',
    );
    if (!device || device.status !== 'active') {
      throw ApiError.unauthorized('DEVICE_UNPAIRED', 'Thiết bị đã bị huỷ ghép');
    }
    return {
      role: 'child',
      deviceId: device._id.toString(),
      childId: device.childId.toString(),
      parentId: device.parentId.toString(),
    };
  }

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (e) {
    if (e.name === 'TokenExpiredError') {
      throw ApiError.unauthorized('TOKEN_EXPIRED', 'Phiên đăng nhập đã hết hạn');
    }
    throw ApiError.unauthorized('TOKEN_INVALID', 'Token không hợp lệ');
  }
  // Kiểm lại DB mỗi request: tài khoản bị khoá/xoá là mất quyền ngay.
  const user = await User.findById(payload.sub).select('role status');
  if (!user || user.status === 'deleted') throw ApiError.unauthorized('TOKEN_INVALID', 'Tài khoản không tồn tại');
  if (user.status === 'locked') {
    throw ApiError.forbidden('ACCOUNT_LOCKED', 'Tài khoản đã bị khoá, liên hệ hỗ trợ');
  }
  return { userId: user._id.toString(), role: user.role };
}

export async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : null;
    req.auth = await resolveAuth(token);
    next();
  } catch (e) {
    next(e);
  }
}
