// Model người dùng (admin, staff, parent): đăng ký, đăng nhập, phân quyền, đăng nhập khuôn mặt.
import mongoose from 'mongoose';

const trustedDeviceSchema = new mongoose.Schema(
  {
    deviceId: { type: String, required: true },
    name: { type: String, default: '' },
    lastUsedAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

const userSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, unique: true, lowercase: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    fullName: { type: String, required: true, trim: true },
    phone: { type: String, default: '' },
    role: { type: String, enum: ['admin', 'staff', 'parent'], default: 'parent', index: true },
    status: {
      type: String,
      enum: ['pending', 'active', 'locked', 'deleted'],
      default: 'pending',
      index: true,
    },
    faceLoginEnabled: { type: Boolean, default: false },
    trustedDevices: { type: [trustedDeviceSchema], default: [] },
    fcmTokens: { type: [String], default: [] },
  },
  { timestamps: true },
);

/** Dữ liệu an toàn để trả về client (không có passwordHash). */
userSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    username: this.username,
    email: this.email,
    fullName: this.fullName,
    phone: this.phone,
    role: this.role,
    status: this.status,
    faceLoginEnabled: this.faceLoginEnabled,
    createdAt: this.createdAt,
  };
};

export const User = mongoose.model('User', userSchema);
