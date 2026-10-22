// Model điểm vị trí máy con gửi lên, dùng cho bản đồ và lịch sử. Tự xoá sau 7 ngày (TTL).
import mongoose from 'mongoose';

const locationSchema = new mongoose.Schema({
  childId: { type: mongoose.Schema.Types.ObjectId, ref: 'Child', required: true },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  accuracy: { type: Number, default: null },
  speed: { type: Number, default: null },
  battery: { type: Number, default: null },
  recordedAt: { type: Date, required: true },
  createdAt: { type: Date, default: Date.now },
});

locationSchema.index({ childId: 1, recordedAt: 1 });
locationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 7 * 24 * 3600 });

export const Location = mongoose.model('Location', locationSchema);
