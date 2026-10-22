// Model điện thoại của con đã ghép QR: token thiết bị (lưu hash), pin, danh sách app, trạng thái.
import mongoose from 'mongoose';

const installedAppSchema = new mongoose.Schema(
  { packageName: String, label: String },
  { _id: false },
);

const deviceSchema = new mongoose.Schema(
  {
    childId: { type: mongoose.Schema.Types.ObjectId, ref: 'Child', required: true, index: true },
    parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    name: { type: String, default: '' },
    model: { type: String, default: '' },
    androidVersion: { type: String, default: '' },
    appVersion: { type: String, default: '' },
    tokenHash: { type: String, index: true },
    // Token riêng cho script giả lập vị trí khi demo, không ảnh hưởng token của máy thật
    simTokenHash: { type: String, index: true, sparse: true },
    pairedAt: { type: Date, default: Date.now },
    lastSeenAt: { type: Date, default: null },
    batteryLevel: { type: Number, default: null },
    installedApps: { type: [installedAppSchema], default: [] },
    permissions: { type: Object, default: {} },
    fcmToken: { type: String, default: '' },
    status: { type: String, enum: ['active', 'unpaired'], default: 'active', index: true },
  },
  { timestamps: true },
);

export const Device = mongoose.model('Device', deviceSchema);
