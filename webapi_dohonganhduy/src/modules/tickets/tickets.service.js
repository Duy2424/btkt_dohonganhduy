// Nghiệp vụ ticket hỗ trợ: phụ huynh tạo / nhắn / xoá khi còn "open"; nhân viên nhận, trả lời, đổi trạng thái
// (open → in_progress → resolved → closed); admin xem & xoá mọi ticket.
import { SupportTicket } from '../../models/SupportTicket.js';
import { User } from '../../models/User.js';
import { ApiError } from '../../utils/ApiError.js';
import { escapeRegex } from '../common.schema.js';
import { STATUS_ORDER } from './tickets.schema.js';

async function toDto(t, { withMessages = false } = {}) {
  const ids = [t.parentId, t.assignedStaffId].filter(Boolean);
  const users = await User.find({ _id: { $in: ids } }).select('fullName');
  const name = (id) => users.find((u) => id && u._id.equals(id))?.fullName;
  const dto = {
    id: t._id.toString(),
    subject: t.subject,
    category: t.category,
    status: t.status,
    parentId: t.parentId.toString(),
    parentName: name(t.parentId),
    assignedStaffId: t.assignedStaffId?.toString() || null,
    assignedStaffName: name(t.assignedStaffId) || null,
    messageCount: t.messages.length,
    lastMessage: t.messages.at(-1)?.content || '',
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  };
  if (withMessages) {
    dto.messages = t.messages.map((m) => ({
      senderId: m.senderId.toString(),
      senderRole: m.senderRole,
      senderName: m.senderName,
      content: m.content,
      createdAt: m.createdAt,
    }));
  }
  return dto;
}

/** Ai được xem ticket: chủ ticket, nhân viên đang xử lý (hoặc ticket còn trong hàng chờ), admin. */
function canView(t, auth) {
  if (auth.role === 'admin') return true;
  if (auth.role === 'parent') return t.parentId.toString() === auth.userId;
  if (auth.role === 'staff') return !t.assignedStaffId || t.assignedStaffId.toString() === auth.userId;
  return false;
}

async function getViewable(id, auth) {
  const t = await SupportTicket.findById(id);
  if (!t || !canView(t, auth)) throw ApiError.notFound('Không tìm thấy ticket');
  return t;
}

export async function list(auth, { page, limit, search, status, scope }) {
  const filter = {};
  if (auth.role === 'parent') filter.parentId = auth.userId;
  if (auth.role === 'staff') {
    if (scope === 'queue') Object.assign(filter, { assignedStaffId: null, status: 'open' });
    else if (scope === 'mine') Object.assign(filter, { assignedStaffId: auth.userId, status: { $in: ['open', 'in_progress'] } });
    else if (scope === 'done') Object.assign(filter, { assignedStaffId: auth.userId, status: { $in: ['resolved', 'closed'] } });
    else filter.$or = [{ assignedStaffId: auth.userId }, { assignedStaffId: null, status: 'open' }];
  }
  if (status) filter.status = status;
  if (search) filter.subject = new RegExp(escapeRegex(search), 'i');

  const [items, total] = await Promise.all([
    SupportTicket.find(filter).sort({ updatedAt: -1 }).skip((page - 1) * limit).limit(limit),
    SupportTicket.countDocuments(filter),
  ]);
  const result = { items: await Promise.all(items.map((t) => toDto(t))), page, limit, total };

  if (auth.role === 'staff') {
    const [queue, mine, done] = await Promise.all([
      SupportTicket.countDocuments({ assignedStaffId: null, status: 'open' }),
      SupportTicket.countDocuments({ assignedStaffId: auth.userId, status: { $in: ['open', 'in_progress'] } }),
      SupportTicket.countDocuments({ assignedStaffId: auth.userId, status: { $in: ['resolved', 'closed'] } }),
    ]);
    result.counts = { queue, mine, done };
  }
  return result;
}

export async function get(auth, id) {
  return toDto(await getViewable(id, auth), { withMessages: true });
}

export async function create(auth, { subject, category, content }) {
  const user = await User.findById(auth.userId).select('fullName');
  const t = await SupportTicket.create({
    parentId: auth.userId,
    subject,
    category,
    messages: [{ senderId: auth.userId, senderRole: 'parent', senderName: user?.fullName, content }],
  });
  return toDto(t, { withMessages: true });
}

export async function claim(auth, id) {
  const t = await SupportTicket.findOneAndUpdate(
    { _id: id, assignedStaffId: null, status: 'open' },
    { $set: { assignedStaffId: auth.userId, status: 'in_progress' } },
    { returnDocument: 'after' },
  );
  if (!t) throw ApiError.conflict('TICKET_TAKEN', 'Ticket đã được nhân viên khác nhận hoặc không còn trong hàng chờ');
  return toDto(t, { withMessages: true });
}

export async function updateStatus(auth, id, status) {
  const t = await getViewable(id, auth);
  if (auth.role === 'parent') throw ApiError.forbidden();
  if (auth.role === 'staff') {
    if (t.assignedStaffId?.toString() !== auth.userId) {
      throw ApiError.forbidden('NOT_ASSIGNED', 'Hãy nhận ticket trước khi đổi trạng thái');
    }
    if (STATUS_ORDER.indexOf(status) <= STATUS_ORDER.indexOf(t.status)) {
      throw ApiError.badRequest('INVALID_TRANSITION', 'Chỉ được chuyển trạng thái theo thứ tự: Mới → Đang xử lý → Đã giải quyết → Đã đóng');
    }
  }
  t.status = status;
  await t.save();
  return toDto(t, { withMessages: true });
}

export async function addMessage(auth, id, content) {
  const t = await getViewable(id, auth);
  if (t.status === 'closed') throw ApiError.badRequest('TICKET_CLOSED', 'Ticket đã đóng, không thể nhắn thêm');
  if (auth.role === 'staff' && t.assignedStaffId?.toString() !== auth.userId) {
    throw ApiError.forbidden('NOT_ASSIGNED', 'Hãy nhận ticket trước khi trả lời');
  }
  const user = await User.findById(auth.userId).select('fullName');
  t.messages.push({ senderId: auth.userId, senderRole: auth.role, senderName: user?.fullName, content });
  // Phụ huynh nhắn thêm vào ticket đã giải quyết → mở lại để nhân viên xem
  if (auth.role === 'parent' && t.status === 'resolved') t.status = 'in_progress';
  await t.save();
  return toDto(t, { withMessages: true });
}

export async function remove(auth, id) {
  const t = await getViewable(id, auth);
  if (auth.role === 'parent' && t.status !== 'open') {
    throw ApiError.badRequest('TICKET_NOT_OPEN', 'Chỉ xoá được ticket khi còn ở trạng thái "Mới"');
  }
  if (auth.role === 'staff') throw ApiError.forbidden();
  await t.deleteOne();
}
