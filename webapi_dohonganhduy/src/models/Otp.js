// Model mã OTP 6 số (xác minh email, đăng nhập, quên mật khẩu). Chỉ lưu hash, hết hạn thì tự xoá (TTL).
import mongoose from 'mongoose';

const otpSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    purpose: { type: String, enum: ['verify_email', 'login', 'reset_password'], required: true },
    codeHash: { type: String, required: true },
    attempts: { type: Number, default: 0 },
    expiresAt: { type: Date, required: true },
    consumedAt: { type: Date, default: null },
    // Thông tin máy đang đăng nhập (chỉ dùng cho purpose = login)
    meta: {
      deviceId: { type: String, default: '' },
      deviceName: { type: String, default: '' },
    },
  },
  { timestamps: true },
);

otpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export const Otp = mongoose.model('Otp', otpSchema);
