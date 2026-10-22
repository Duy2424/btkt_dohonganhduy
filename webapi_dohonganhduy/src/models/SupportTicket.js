// Model ticket hỗ trợ: phụ huynh tạo, nhân viên nhận & trả lời, admin xem tất cả.
import mongoose from 'mongoose';

const messageSchema = new mongoose.Schema(
  {
    senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    senderRole: { type: String, enum: ['admin', 'staff', 'parent'], required: true },
    senderName: { type: String, default: '' },
    content: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

const supportTicketSchema = new mongoose.Schema(
  {
    parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    assignedStaffId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    subject: { type: String, required: true, trim: true },
    category: { type: String, enum: ['account', 'device', 'bug', 'other'], default: 'other' },
    status: {
      type: String,
      enum: ['open', 'in_progress', 'resolved', 'closed'],
      default: 'open',
      index: true,
    },
    messages: { type: [messageSchema], default: [] },
  },
  { timestamps: true },
);

export const SupportTicket = mongoose.model('SupportTicket', supportTicketSchema);
