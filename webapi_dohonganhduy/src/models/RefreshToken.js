// Model refresh token: lưu hash, xoay vòng mỗi lần refresh, thu hồi khi logout, hết hạn thì tự xoá (TTL).
// purpose: "session" = phiên đăng nhập thường, "face" = token riêng cho đăng nhập khuôn mặt trên máy tin cậy.
import mongoose from 'mongoose';

const refreshTokenSchema = new mongoose.Schema(
  {
    ownerType: { type: String, enum: ['user', 'device'], default: 'user' },
    ownerId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    purpose: { type: String, enum: ['session', 'face'], default: 'session' },
    deviceId: { type: String, default: '' },
    tokenHash: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true },
    revokedAt: { type: Date, default: null },
    replacedBy: { type: mongoose.Schema.Types.ObjectId, default: null },
  },
  { timestamps: true },
);

refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export const RefreshToken = mongoose.model('RefreshToken', refreshTokenSchema);
