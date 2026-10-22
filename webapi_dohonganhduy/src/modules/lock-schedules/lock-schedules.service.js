// Nghiệp vụ lịch khoá máy: CRUD theo con, nhãn "Đang hiệu lực", báo máy con tải lại cấu hình khi đổi.
import { LockSchedule } from '../../models/LockSchedule.js';
import { ApiError } from '../../utils/ApiError.js';
import { isWithinWeeklyWindow } from '../../utils/time.js';
import { getOwnedChild } from '../children/children.service.js';
import { notifyConfigChanged } from '../devices/devices.notify.js';

export function toLockDto(l, now = new Date()) {
  return {
    id: l._id.toString(),
    childId: l.childId.toString(),
    name: l.name,
    daysOfWeek: l.daysOfWeek,
    startTime: l.startTime,
    endTime: l.endTime,
    allowedPackages: l.allowedPackages,
    enabled: l.enabled,
    activeNow: l.enabled && isWithinWeeklyWindow(l, now),
  };
}

async function getOwned(parentId, id) {
  const l = await LockSchedule.findOne({ _id: id, parentId });
  if (!l) throw ApiError.notFound('Không tìm thấy lịch khoá');
  return l;
}

export async function list(parentId, childId) {
  await getOwnedChild(parentId, childId);
  const items = await LockSchedule.find({ parentId, childId }).sort({ startTime: 1 });
  return { items: items.map((l) => toLockDto(l)), total: items.length };
}

export async function create(parentId, input) {
  await getOwnedChild(parentId, input.childId);
  const l = await LockSchedule.create({ ...input, parentId });
  notifyConfigChanged(l.childId);
  return toLockDto(l);
}

export async function update(parentId, id, input) {
  const l = await getOwned(parentId, id);
  for (const [k, v] of Object.entries(input)) if (v !== undefined) l[k] = v;
  if (l.startTime === l.endTime) {
    throw ApiError.badRequest('VALIDATION_ERROR', 'Giờ bắt đầu và kết thúc không được trùng nhau', [{ field: 'endTime', message: 'Giờ bắt đầu và kết thúc không được trùng nhau' }]);
  }
  await l.save();
  notifyConfigChanged(l.childId);
  return toLockDto(l);
}

export async function remove(parentId, id) {
  const l = await getOwned(parentId, id);
  await l.deleteOne();
  notifyConfigChanged(l.childId);
}
