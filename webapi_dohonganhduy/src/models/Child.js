// Model hồ sơ con, kèm vị trí cuối và các ngày nghỉ học (dùng cho Giờ học an toàn).
import mongoose from 'mongoose';

const lastLocationSchema = new mongoose.Schema(
  {
    lat: Number,
    lng: Number,
    accuracy: Number,
    battery: Number,
    at: Date,
  },
  { _id: false },
);

const childSchema = new mongoose.Schema(
  {
    parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, required: true, trim: true },
    birthYear: { type: Number, default: null },
    schoolName: { type: String, default: '' },
    avatarColor: { type: String, default: '#14B8A6' },
    deviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Device', default: null },
    lastLocation: { type: lastLocationSchema, default: null },
    schoolOffDates: { type: [String], default: [] },
  },
  { timestamps: true },
);

export const Child = mongoose.model('Child', childSchema);
