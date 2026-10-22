// Model vùng an toàn (nhà / trường / khác): tâm + bán kính, bật/tắt báo vào/ra.
import mongoose from 'mongoose';

const geofenceSchema = new mongoose.Schema(
  {
    parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    childId: { type: mongoose.Schema.Types.ObjectId, ref: 'Child', required: true, index: true },
    name: { type: String, required: true, trim: true },
    type: { type: String, enum: ['home', 'school', 'other'], default: 'other' },
    center: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
    },
    radiusM: { type: Number, required: true, min: 50, max: 1000 },
    notifyEnter: { type: Boolean, default: true },
    notifyExit: { type: Boolean, default: true },
    active: { type: Boolean, default: true },
    // Kết quả lần đánh giá trước, để phát hiện vào/ra. Lưu DB vì server không giữ trạng thái trong RAM.
    lastInside: { type: Boolean, default: null },
  },
  { timestamps: true },
);

export const Geofence = mongoose.model('Geofence', geofenceSchema);
