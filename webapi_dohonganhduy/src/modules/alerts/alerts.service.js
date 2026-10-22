// Nghiệp vụ cảnh báo: tạo cảnh báo (chống trùng bằng dedupeKey, đẩy socket và push), đọc, đánh dấu, xoá.
import { Alert } from '../../models/Alert.js';
import { Child } from '../../models/Child.js';
import { ApiError } from '../../utils/ApiError.js';
import { logger } from '../../utils/logger.js';
import { emitToParent } from '../../sockets/index.js';
import { EVENTS } from '../../sockets/events.js';
import { pushToUser } from '../../services/push.service.js';

export function toAlertDto(a, childName) {
  return {
    id: a._id.toString(),
    childId: a.childId.toString(),
    childName: childName ?? undefined,
    type: a.type,
    level: a.level,
    title: a.title,
    message: a.message,
    location: a.location,
    silent: a.silent,
    readAt: a.readAt,
    createdAt: a.createdAt,
  };
}

/**
 * Tạo cảnh báo. Trùng dedupeKey (đã báo rồi) → trả về null, không báo lại.
 * silent = true: chỉ ghi nhật ký, không push.
 */
export async function createAlert({ parentId, childId, type, level = 'info', title, message = '', location = null, dedupeKey, silent = false }) {
  let alert;
  try {
    alert = await Alert.create({ parentId, childId, type, level, title, message, location, dedupeKey, silent });
  } catch (e) {
    if (e.code === 11000) return null;
    throw e;
  }
  const child = await Child.findById(childId).select('name');
  const dto = toAlertDto(alert, child?.name);
  emitToParent(parentId, EVENTS.ALERT_NEW, dto);
  if (!silent) {
    pushToUser(parentId, {
      title: child ? `${child.name}: ${title}` : title,
      body: message,
      level,
      data: { type: 'alert', alertId: dto.id, childId: dto.childId },
    }).catch((e) => logger.warn('Push cảnh báo lỗi:', e.message));
  }
  return alert;
}

export async function list(parentId, { childId, type, unread, page, limit }) {
  const filter = { parentId };
  if (childId) filter.childId = childId;
  if (type) filter.type = type;
  if (unread) filter.readAt = null;
  const [items, total, unreadCount, children] = await Promise.all([
    Alert.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
    Alert.countDocuments(filter),
    Alert.countDocuments({ parentId, readAt: null }),
    Child.find({ parentId }).select('name'),
  ]);
  const names = new Map(children.map((c) => [c._id.toString(), c.name]));
  return {
    items: items.map((a) => toAlertDto(a, names.get(a.childId.toString()))),
    page,
    limit,
    total,
    unreadCount,
  };
}

export async function markRead(parentId, id) {
  const alert = await Alert.findOneAndUpdate(
    { _id: id, parentId },
    { $set: { readAt: new Date() } },
    { returnDocument: 'after' },
  );
  if (!alert) throw ApiError.notFound('Không tìm thấy cảnh báo');
  return toAlertDto(alert);
}

export async function markAllRead(parentId) {
  const res = await Alert.updateMany({ parentId, readAt: null }, { $set: { readAt: new Date() } });
  return { updated: res.modifiedCount };
}

export async function remove(parentId, id) {
  const res = await Alert.deleteOne({ _id: id, parentId });
  if (!res.deletedCount) throw ApiError.notFound('Không tìm thấy cảnh báo');
}

export async function removeRead(parentId) {
  const res = await Alert.deleteMany({ parentId, readAt: { $ne: null } });
  return { deleted: res.deletedCount };
}
