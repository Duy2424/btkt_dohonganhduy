// Nghiệp vụ xác thực: đăng ký + xác minh email, đăng nhập 2 bước (mật khẩu + OTP), refresh xoay vòng,
// đăng nhập khuôn mặt (máy tin cậy), quên / đặt lại mật khẩu.
import bcrypt from 'bcryptjs';
import mongoose from 'mongoose';
import { User } from '../../models/User.js';
import { Otp } from '../../models/Otp.js';
import { ApiError } from '../../utils/ApiError.js';
import { logger } from '../../utils/logger.js';
import { createOtp, maskEmail, verifyOtp, OTP_RESEND_SECONDS } from '../../services/otp.service.js';
import { sendOtpEmail } from '../../services/email.service.js';
import {
  findValidRefreshToken,
  issueRefreshToken,
  revokeAllForUser,
  revokeRefreshToken,
  rotateRefreshToken,
  signAccessToken,
} from '../../services/token.service.js';

export const BCRYPT_ROUNDS = 10;
// So sánh với hash giả khi username không tồn tại → thời gian phản hồi như nhau, không lộ username.
const DUMMY_HASH = bcrypt.hashSync('conan-dummy-password-1', BCRYPT_ROUNDS);
const MAX_TRUSTED_DEVICES = 10;

/** Tạo OTP + gửi mail. Gửi lỗi thì huỷ OTP và báo rõ. */
async function sendOtp(user, purpose, meta) {
  const { otp, code } = await createOtp(user._id, purpose, meta);
  try {
    await sendOtpEmail(user.email, code, purpose, user.fullName);
  } catch (e) {
    logger.error('Gửi email OTP thất bại:', e.message);
    await otp.deleteOne();
    throw new ApiError(502, 'EMAIL_SEND_FAILED', 'Không gửi được email OTP, vui lòng thử lại sau');
  }
  return {
    otpSessionId: otp._id.toString(),
    maskedEmail: maskEmail(user.email),
    resendAfter: OTP_RESEND_SECONDS,
  };
}

async function issueSession(user, deviceId = '') {
  const { raw } = await issueRefreshToken(user._id, { purpose: 'session', deviceId });
  return { accessToken: signAccessToken(user), refreshToken: raw, user: user.toPublic() };
}

function assertActive(user) {
  if (!user || user.status === 'deleted') {
    throw ApiError.unauthorized('INVALID_CREDENTIALS', 'Sai tên đăng nhập hoặc mật khẩu');
  }
  if (user.status === 'locked') {
    throw ApiError.forbidden('ACCOUNT_LOCKED', 'Tài khoản đã bị khoá, liên hệ hỗ trợ');
  }
  if (user.status === 'pending') {
    throw new ApiError(403, 'ACCOUNT_PENDING', 'Tài khoản chưa xác minh email', { email: user.email });
  }
}

export async function register({ fullName, username, email, password, phone }) {
  const [byEmail, byUsername] = await Promise.all([
    User.findOne({ email }),
    User.findOne({ username }),
  ]);
  // Tài khoản đang chờ xác minh của chính email này → cho đăng ký lại (ghi đè) & gửi mã mới.
  const reusable =
    byEmail && byEmail.status === 'pending' && (!byUsername || byUsername.id === byEmail.id);

  if (!reusable) {
    const details = [];
    if (byEmail) details.push({ field: 'email', message: 'Email đã được sử dụng' });
    if (byUsername) details.push({ field: 'username', message: 'Tên đăng nhập đã tồn tại' });
    if (details.length) {
      throw ApiError.conflict(byEmail ? 'EMAIL_TAKEN' : 'USERNAME_TAKEN', details[0].message, details);
    }
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const user = reusable ? byEmail : new User({ email, role: 'parent', status: 'pending' });
  Object.assign(user, { fullName, username, phone, passwordHash });
  await user.save();
  return sendOtp(user, 'verify_email');
}

export async function verifyEmail({ otpSessionId, code }) {
  const otp = await verifyOtp(otpSessionId, code, 'verify_email');
  const user = await User.findById(otp.userId);
  if (!user) throw ApiError.notFound('Không tìm thấy tài khoản');
  if (user.status === 'pending') {
    user.status = 'active';
    await user.save();
  }
  return { user: user.toPublic() };
}

export async function resendOtp(input) {
  if (input.otpSessionId) {
    const old = mongoose.isValidObjectId(input.otpSessionId) ? await Otp.findById(input.otpSessionId) : null;
    if (!old) {
      throw ApiError.badRequest('OTP_SESSION_GONE', 'Phiên xác thực đã hết, vui lòng thực hiện lại từ đầu');
    }
    const user = await User.findById(old.userId);
    if (!user) throw ApiError.notFound('Không tìm thấy tài khoản');
    return sendOtp(user, old.purpose, old.meta);
  }
  const user = await User.findOne({ email: input.email, status: 'pending' });
  if (!user) throw ApiError.badRequest('NOT_PENDING', 'Tài khoản không tồn tại hoặc đã được xác minh');
  return sendOtp(user, 'verify_email');
}

export async function login({ username, password, deviceId, deviceName }) {
  const user = await User.findOne({ username, status: { $ne: 'deleted' } });
  const passwordOk = await bcrypt.compare(password, user?.passwordHash || DUMMY_HASH);
  if (!user || !passwordOk) {
    throw ApiError.unauthorized('INVALID_CREDENTIALS', 'Sai tên đăng nhập hoặc mật khẩu');
  }
  assertActive(user);
  return sendOtp(user, 'login', { deviceId, deviceName });
}

export async function verifyLoginOtp({ otpSessionId, code }) {
  const otp = await verifyOtp(otpSessionId, code, 'login');
  const user = await User.findById(otp.userId);
  assertActive(user);

  // Máy vừa đăng nhập đủ mật khẩu + OTP → ghi nhận là máy tin cậy (điều kiện để bật đăng nhập khuôn mặt).
  const { deviceId, deviceName } = otp.meta || {};
  if (deviceId) {
    user.trustedDevices = user.trustedDevices.filter((d) => d.deviceId !== deviceId);
    user.trustedDevices.push({ deviceId, name: deviceName, lastUsedAt: new Date() });
    user.trustedDevices = user.trustedDevices.slice(-MAX_TRUSTED_DEVICES);
    await user.save();
  }
  return issueSession(user, deviceId);
}

export async function refresh({ refreshToken }) {
  const doc = await findValidRefreshToken(refreshToken, 'session');
  const user = await User.findById(doc.ownerId);
  assertActive(user);
  const newRefresh = await rotateRefreshToken(doc);
  return { accessToken: signAccessToken(user), refreshToken: newRefresh, user: user.toPublic() };
}

export async function faceLogin({ deviceId, refreshToken }) {
  const doc = await findValidRefreshToken(refreshToken, 'face');
  if (doc.deviceId !== deviceId) {
    throw ApiError.unauthorized('FACE_DEVICE_MISMATCH', 'Thiết bị không khớp, hãy đăng nhập bằng mật khẩu');
  }
  const user = await User.findById(doc.ownerId);
  assertActive(user);
  const trusted = user.trustedDevices.find((d) => d.deviceId === deviceId);
  if (!user.faceLoginEnabled || !trusted) {
    throw ApiError.forbidden('FACE_LOGIN_DISABLED', 'Máy này chưa bật đăng nhập khuôn mặt');
  }
  trusted.lastUsedAt = new Date();
  await user.save();
  const faceToken = await rotateRefreshToken(doc);
  return { ...(await issueSession(user, deviceId)), faceToken };
}

export async function logout({ refreshToken }) {
  await revokeRefreshToken(refreshToken);
}

export async function forgotPassword({ email }) {
  const user = await User.findOne({ email, status: { $in: ['active', 'pending'] } });
  if (!user) {
    // Không tiết lộ email có tồn tại hay không: trả về phiên giả.
    return {
      otpSessionId: new mongoose.Types.ObjectId().toString(),
      maskedEmail: maskEmail(email),
      resendAfter: OTP_RESEND_SECONDS,
    };
  }
  return sendOtp(user, 'reset_password');
}

export async function resetPassword({ otpSessionId, code, newPassword }) {
  const otp = await verifyOtp(otpSessionId, code, 'reset_password');
  const user = await User.findById(otp.userId);
  if (!user) throw ApiError.notFound('Không tìm thấy tài khoản');
  user.passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
  if (user.status === 'pending') user.status = 'active'; // đã chứng minh sở hữu email
  await user.save();
  await revokeAllForUser(user._id);
}

export async function me(userId) {
  const user = await User.findById(userId);
  if (!user) throw ApiError.notFound('Không tìm thấy tài khoản');
  return user.toPublic();
}
