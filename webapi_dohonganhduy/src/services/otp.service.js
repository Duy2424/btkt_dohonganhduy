// Tạo & kiểm tra OTP 6 số: lưu hash (sha256 + OTP_PEPPER), hết hạn 5 phút, sai 5 lần thì huỷ, gửi lại sau 60 giây.
import crypto from 'node:crypto';
import { env } from '../config/env.js';
import { Otp } from '../models/Otp.js';
import { ApiError } from '../utils/ApiError.js';

export const OTP_TTL_MS = 5 * 60 * 1000;
export const OTP_RESEND_SECONDS = 60;
export const OTP_MAX_ATTEMPTS = 5;

function hashCode(otpId, code) {
  return crypto.createHash('sha256').update(`${otpId}:${code}:${env.OTP_PEPPER}`).digest('hex');
}

/** Tạo OTP mới và huỷ các OTP cũ cùng mục đích. Trả về { otp, code }, code chỉ dùng để gửi mail. */
export async function createOtp(userId, purpose, meta = {}) {
  const recent = await Otp.findOne({ userId, purpose, consumedAt: null }).sort({ createdAt: -1 });
  if (recent) {
    const elapsed = (Date.now() - recent.createdAt.getTime()) / 1000;
    if (elapsed < OTP_RESEND_SECONDS) {
      const retryAfter = Math.ceil(OTP_RESEND_SECONDS - elapsed);
      throw ApiError.tooMany('OTP_COOLDOWN', `Vui lòng đợi ${retryAfter} giây để gửi lại mã`, {
        retryAfter,
      });
    }
  }
  await Otp.deleteMany({ userId, purpose });

  const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
  const otp = new Otp({
    userId,
    purpose,
    codeHash: 'pending',
    expiresAt: new Date(Date.now() + OTP_TTL_MS),
    meta,
  });
  otp.codeHash = hashCode(otp._id.toString(), code);
  await otp.save();
  return { otp, code };
}

/** Kiểm tra mã. Đúng → đánh dấu đã dùng và trả về bản ghi OTP. */
export async function verifyOtp(otpSessionId, code, purpose) {
  const otp = await Otp.findOne({ _id: otpSessionId, purpose }).catch(() => null);
  if (!otp || otp.consumedAt) {
    throw ApiError.badRequest('OTP_NOT_FOUND', 'Mã OTP không tồn tại hoặc đã được dùng, hãy gửi lại mã');
  }
  if (otp.expiresAt < new Date()) {
    throw ApiError.badRequest('OTP_EXPIRED', 'Mã OTP đã hết hạn, hãy gửi lại mã');
  }
  const expected = Buffer.from(otp.codeHash, 'hex');
  const actual = Buffer.from(hashCode(otp._id.toString(), String(code)), 'hex');
  if (!crypto.timingSafeEqual(expected, actual)) {
    otp.attempts += 1;
    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      await otp.deleteOne();
      throw ApiError.badRequest('OTP_TOO_MANY_ATTEMPTS', 'Nhập sai quá 5 lần, mã đã bị huỷ. Hãy gửi lại mã');
    }
    await otp.save();
    const remaining = OTP_MAX_ATTEMPTS - otp.attempts;
    throw ApiError.badRequest('OTP_INVALID', `Mã OTP không đúng, còn ${remaining} lần thử`, { remaining });
  }
  otp.consumedAt = new Date();
  await otp.save();
  return otp;
}

/** "duy@gmail.com" → "d***@gmail.com" */
export function maskEmail(email) {
  const [name, domain] = email.split('@');
  return `${name[0]}***@${domain}`;
}
