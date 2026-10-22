// Model mã ghép QR: phụ huynh tạo, máy con quét. Lưu hash, dùng một lần, hết hạn sau 10 phút.
import mongoose from 'mongoose';

const pairingCodeSchema = new mongoose.Schema(
  {
    parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    childId: { type: mongoose.Schema.Types.ObjectId, ref: 'Child', required: true },
    codeHash: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true },
    usedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// Giữ thêm 1 giờ sau khi hết hạn để còn báo được "mã đã hết hạn" thay vì "mã không tồn tại".
pairingCodeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 3600 });

export const PairingCode = mongoose.model('PairingCode', pairingCodeSchema);
