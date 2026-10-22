// Model lịch khoá máy: ngày trong tuần + giờ bắt đầu/kết thúc (cho phép qua nửa đêm) + app được phép.
import mongoose from 'mongoose';

const lockScheduleSchema = new mongoose.Schema(
  {
    parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    childId: { type: mongoose.Schema.Types.ObjectId, ref: 'Child', required: true, index: true },
    name: { type: String, required: true, trim: true },
    daysOfWeek: { type: [Number], required: true },
    startTime: { type: String, required: true },
    endTime: { type: String, required: true },
    allowedPackages: { type: [String], default: [] },
    enabled: { type: Boolean, default: true },
  },
  { timestamps: true },
);

export const LockSchedule = mongoose.model('LockSchedule', lockScheduleSchema);
