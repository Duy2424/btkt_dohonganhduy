// Nghiệp vụ tài khoản của chính người dùng: sửa hồ sơ, đổi mật khẩu, bật/tắt đăng nhập khuôn mặt, lưu FCM token.
// Dữ liệu khuôn mặt không gửi lên server. Server chỉ ghi nhận máy tin cậy và cấp token khuôn mặt.
import bcrypt from 'bcryptjs';
import { User } from '../../models/User.js';
import { ApiError } from '../../utils/ApiError.js';
import { BCRYPT_ROUNDS } from '../auth/auth.service.js';
import { issueRefreshToken } from '../../services/token.service.js';
import { RefreshToken } from '../../models/RefreshToken.js';

async function getUser(userId) {
  const user = await User.findById(userId);
  if (!user) throw ApiError.notFound('Không tìm thấy tài khoản');
  return user;
}

export async function updateMe(userId, { fullName, phone }) {
  const user = await getUser(userId);
  if (fullName !== undefined) user.fullName = fullName;
  if (phone !== undefined) user.phone = phone;
  await user.save();
  return user.toPublic();
}

export async function changePassword(userId, { currentPassword, newPassword }) {
  const user = await getUser(userId);
  if (!(await bcrypt.compare(currentPassword, user.passwordHash))) {
    throw ApiError.badRequest('WRONG_PASSWORD', 'Mật khẩu hiện tại không đúng', [
      { field: 'currentPassword', message: 'Mật khẩu hiện tại không đúng' },
    ]);
  }
  user.passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
  await user.save();
}

export async function setFaceLogin(userId, { enabled, deviceId, deviceName, password }) {
  const user = await getUser(userId);
  if (!enabled) {
    await RefreshToken.updateMany(
      { ownerId: user._id, purpose: 'face', deviceId, revokedAt: null },
      { revokedAt: new Date() },
    );
    const stillActive = await RefreshToken.exists({ ownerId: user._id, purpose: 'face', revokedAt: null });
    user.faceLoginEnabled = Boolean(stillActive);
    await user.save();
    return { faceLoginEnabled: user.faceLoginEnabled };
  }

  // Bật: bắt buộc nhập lại mật khẩu
  if (!password || !(await bcrypt.compare(password, user.passwordHash))) {
    throw ApiError.badRequest('WRONG_PASSWORD', 'Mật khẩu không đúng', [
      { field: 'password', message: 'Mật khẩu không đúng' },
    ]);
  }
  if (!user.trustedDevices.some((d) => d.deviceId === deviceId)) {
    user.trustedDevices.push({ deviceId, name: deviceName, lastUsedAt: new Date() });
  }
  user.faceLoginEnabled = true;
  await user.save();
  await RefreshToken.updateMany(
    { ownerId: user._id, purpose: 'face', deviceId, revokedAt: null },
    { revokedAt: new Date() },
  );
  const { raw } = await issueRefreshToken(user._id, { purpose: 'face', deviceId });
  return { faceLoginEnabled: true, faceToken: raw };
}

export async function setFcmToken(userId, { token }) {
  const user = await getUser(userId);
  user.fcmTokens = [...user.fcmTokens.filter((t) => t !== token), token].slice(-5);
  await user.save();
}

