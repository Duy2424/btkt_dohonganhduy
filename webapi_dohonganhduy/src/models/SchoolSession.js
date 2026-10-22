// Model buổi học trong thời khoá biểu, gắn với vùng "Trường". Đây là dữ liệu cho Giờ học an toàn.
import mongoose from 'mongoose';

const schoolSessionSchema = new mongoose.Schema(
  {
    parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    childId: { type: mongoose.Schema.Types.ObjectId, ref: 'Child', required: true, index: true },
    geofenceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Geofence', required: true },
    daysOfWeek: { type: [Number], required: true },
    startTime: { type: String, required: true },
    endTime: { type: String, required: true },
    label: { type: String, default: '' },
    graceMinutes: { type: Number, default: 15 },
    outsideToleranceMinutes: { type: Number, default: 5 },
    active: { type: Boolean, default: true },
    // Buổi học tạm do script simulate tạo khi demo, xoá khi demo xong.
    isDemo: { type: Boolean, default: false },
    // Trạng thái của engine trong ngày. Lưu DB chứ không giữ RAM vì server có thể restart bất cứ lúc nào.
    guardState: {
      date: { type: String, default: '' }, // YYYY-MM-DD giờ VN
      arrived: { type: Boolean, default: false }, // đã vào trường trong buổi này chưa
      outsideSince: { type: Date, default: null }, // mốc bắt đầu ở ngoài vùng trong giờ học
    },
  },
  { timestamps: true },
);

export const SchoolSession = mongoose.model('SchoolSession', schoolSessionSchema);
