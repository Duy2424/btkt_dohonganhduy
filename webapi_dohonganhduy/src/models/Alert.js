// Model cảnh báo gửi phụ huynh (Giờ học an toàn, vào/ra vùng, SOS, pin yếu, quyền bị tắt).
// dedupeKey unique giúp mỗi loại cảnh báo chỉ tạo 1 lần / buổi học / con.
import mongoose from 'mongoose';

export const ALERT_TYPES = [
  'left_school_during_class',
  'not_arrived_school',
  'device_offline_school_hours',
  'returned_to_school',
  'school_dismissed',
  'geofence_enter',
  'geofence_exit',
  'sos',
  'low_battery',
  'permission_revoked',
];

const pointSchema = new mongoose.Schema(
  { lat: Number, lng: Number, accuracy: Number },
  { _id: false },
);

const alertSchema = new mongoose.Schema({
  parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  childId: { type: mongoose.Schema.Types.ObjectId, ref: 'Child', required: true, index: true },
  type: { type: String, enum: ALERT_TYPES, required: true },
  level: { type: String, enum: ['info', 'warning', 'danger'], default: 'info' },
  title: { type: String, required: true },
  message: { type: String, default: '' },
  location: { type: pointSchema, default: null },
  // true = chỉ ghi nhật ký, không push (vd tan học bình thường)
  silent: { type: Boolean, default: false },
  dedupeKey: { type: String, default: undefined },
  readAt: { type: Date, default: null },
  createdAt: { type: Date, default: Date.now, index: true },
});

alertSchema.index({ dedupeKey: 1 }, { unique: true, sparse: true });

export const Alert = mongoose.model('Alert', alertSchema);
