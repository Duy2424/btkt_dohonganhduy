// Nối engine Giờ học an toàn với DB: đọc buổi học + vùng + vị trí của con, chạy engine,
// lưu trạng thái mới vào SchoolSession.guardState và tạo cảnh báo (chống trùng: 1 lần / buổi / ngày / loại).
import { Child } from '../../models/Child.js';
import { Device } from '../../models/Device.js';
import { Alert } from '../../models/Alert.js';
import { SchoolSession } from '../../models/SchoolSession.js';
import { localDateKey, isoWeekday } from '../../utils/time.js';
import { createAlert } from '../alerts/alerts.service.js';
import { evaluateSession } from './school-guard.engine.js';

export const dedupeKeyOf = (childId, sessionId, date, type) => `${childId}:${sessionId}:${date}:${type}`;

/** Đánh giá mọi buổi học hôm nay của một con tại thời điểm `now`. */
export async function evaluateChild(childId, now = new Date()) {
  const sessions = await SchoolSession.find({ childId, active: true, daysOfWeek: isoWeekday(now) }).populate('geofenceId');
  if (!sessions.length) return [];

  const [child, device] = await Promise.all([
    Child.findById(childId),
    Device.findOne({ childId, status: 'active' }),
  ]);
  if (!child) return [];

  const today = localDateKey(now);
  const created = [];
  for (const session of sessions) {
    const fence = session.geofenceId;
    if (!fence || !fence.active) continue;

    const prefix = dedupeKeyOf(child._id, session._id, today, '');
    const sent = await Alert.find({ dedupeKey: { $regex: `^${prefix}` } }).select('type');

    const { alerts, state } = evaluateSession({
      session,
      fence,
      point: child.lastLocation?.lat ? child.lastLocation : null,
      lastSeenAt: device?.lastSeenAt ?? null,
      now,
      offToday: child.schoolOffDates.includes(today),
      state: session.guardState,
      sentTypes: sent.map((a) => a.type),
      childName: child.name,
    });

    await SchoolSession.updateOne({ _id: session._id }, { $set: { guardState: state } });

    for (const a of alerts) {
      const alert = await createAlert({
        ...a,
        parentId: child.parentId,
        childId: child._id,
        dedupeKey: dedupeKeyOf(child._id, session._id, today, a.type),
      });
      if (alert) created.push(alert);
    }
  }
  return created;
}

/** Chạy cho mọi con có buổi học hôm nay. Job mỗi phút gọi hàm này. */
export async function evaluateAll(now = new Date()) {
  const childIds = await SchoolSession.distinct('childId', { active: true, daysOfWeek: isoWeekday(now) });
  let count = 0;
  for (const childId of childIds) {
    count += (await evaluateChild(childId, now)).length;
  }
  return count;
}
