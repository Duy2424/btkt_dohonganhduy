// Cấp và kiểm tra token: JWT access token, refresh token xoay vòng (lưu hash), token thiết bị của máy con.
import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { RefreshToken } from '../models/RefreshToken.js';
import { ApiError } from '../utils/ApiError.js';

export const DEVICE_TOKEN_PREFIX = 'dev_';

/** Hash một token để lưu DB (DB lộ cũng không dùng được token). */
export function hashToken(raw) {
  return crypto.createHmac('sha256', env.JWT_REFRESH_SECRET).update(raw).digest('hex');
}

function randomToken(bytes = 48) {
  return crypto.randomBytes(bytes).toString('base64url');
}

// Claim trong access token: sub (id người dùng), username, role, iss (server phát hành),
// aud (app được phép dùng token), jti (mã riêng của từng token), iat và exp (lúc cấp, lúc hết hạn).
export function signAccessToken(user) {
  return jwt.sign({ username: user.username, role: user.role }, env.JWT_ACCESS_SECRET, {
    subject: user._id.toString(),
    issuer: env.JWT_ISSUER,
    audience: env.JWT_AUDIENCE,
    jwtid: crypto.randomUUID(),
    expiresIn: env.ACCESS_TOKEN_TTL,
    algorithm: 'HS256',
  });
}

/** Kiểm chữ ký, hạn dùng, server phát hành và app nhận token. Sai một trong các điều kiện là từ chối. */
export function verifyAccessToken(token) {
  return jwt.verify(token, env.JWT_ACCESS_SECRET, {
    algorithms: ['HS256'],
    issuer: env.JWT_ISSUER,
    audience: env.JWT_AUDIENCE,
  });
}

/** Tạo refresh token mới cho user, trả về chuỗi gốc (chỉ client giữ). */
export async function issueRefreshToken(userId, { purpose = 'session', deviceId = '' } = {}) {
  const raw = randomToken();
  const doc = await RefreshToken.create({
    ownerType: 'user',
    ownerId: userId,
    purpose,
    deviceId,
    tokenHash: hashToken(raw),
    expiresAt: new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 3600 * 1000),
  });
  return { raw, doc };
}

/** Tìm refresh token còn hiệu lực. Token đã thu hồi mà bị dùng lại → thu hồi cả họ token (nghi bị đánh cắp). */
export async function findValidRefreshToken(raw, purpose = 'session') {
  const doc = await RefreshToken.findOne({ tokenHash: hashToken(raw || ''), purpose });
  if (!doc) throw ApiError.unauthorized('REFRESH_INVALID', 'Phiên đăng nhập không hợp lệ');
  if (doc.revokedAt) {
    await RefreshToken.updateMany(
      { ownerId: doc.ownerId, purpose, revokedAt: null },
      { revokedAt: new Date() },
    );
    throw ApiError.unauthorized('REFRESH_REUSED', 'Phiên đăng nhập đã bị thu hồi, vui lòng đăng nhập lại');
  }
  if (doc.expiresAt < new Date()) {
    throw ApiError.unauthorized('REFRESH_EXPIRED', 'Phiên đăng nhập đã hết hạn');
  }
  return doc;
}

/** Xoay vòng: thu hồi token cũ, cấp token mới cùng loại. */
export async function rotateRefreshToken(doc) {
  const next = await issueRefreshToken(doc.ownerId, { purpose: doc.purpose, deviceId: doc.deviceId });
  doc.revokedAt = new Date();
  doc.replacedBy = next.doc._id;
  await doc.save();
  return next.raw;
}

export async function revokeRefreshToken(raw) {
  await RefreshToken.updateOne(
    { tokenHash: hashToken(raw || ''), revokedAt: null },
    { revokedAt: new Date() },
  );
}

export async function revokeAllForUser(userId, purpose) {
  const filter = { ownerId: userId, revokedAt: null };
  if (purpose) filter.purpose = purpose;
  await RefreshToken.updateMany(filter, { revokedAt: new Date() });
}

/** Token cho máy con (không hết hạn, thu hồi bằng cách huỷ ghép). */
export function generateDeviceToken() {
  return DEVICE_TOKEN_PREFIX + randomToken(32);
}

/** Mã ghép QR ngẫu nhiên 32 byte (base64url). */
export function generatePairingCode() {
  return randomToken(32);
}
