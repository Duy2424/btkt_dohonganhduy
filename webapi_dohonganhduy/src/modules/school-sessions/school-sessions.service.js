// Nghiệp vụ thời khoá biểu (buổi học): CRUD, chỉ gắn với vùng loại "Trường", kiểm tra trùng giờ cùng ngày.
import { SchoolSession } from '../../models/SchoolSession.js';
import { Geofence } from '../../models/Geofence.js';
import { ApiError } from '../../utils/ApiError.js';
import { getOwnedChild } from '../children/children.service.js';
import { notifyConfigChanged } from '../devices/devices.notify.js';

const DAY_NAMES = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

export function toSessionDto(s, fence) {
  return {
    id: s._id.toString(),
    childId: s.childId.toString(),
    geofenceId: s.geofenceId.toString(),
    geofenceName: fence?.name,
    daysOfWeek: s.daysOfWeek,
    startTime: s.startTime,
    endTime: s.endTime,
    label: s.label,
    graceMinutes: s.graceMinutes,
    outsideToleranceMinutes: s.outsideToleranceMinutes,
    active: s.active,
    isDemo: s.isDemo,
  };
}

async function getOwned(parentId, id) {
  const s = await SchoolSession.findOne({ _id: id, parentId });
  if (!s) throw ApiError.notFound('Không tìm thấy buổi học');
  return s;
}

async function assertSchoolFence(parentId, childId, geofenceId) {
  const fence = await Geofence.findOne({ _id: geofenceId, parentId, childId });
  if (!fence) throw ApiError.badRequest('GEOFENCE_NOT_FOUND', 'Không tìm thấy vùng trường', [{ field: 'geofenceId', message: 'Hãy chọn vùng trường' }]);
  if (fence.type !== 'school') {
    throw ApiError.badRequest('NOT_SCHOOL_FENCE', 'Buổi học phải gắn với vùng loại "Trường"', [
      { field: 'geofenceId', message: 'Vùng này không phải loại "Trường"' },
    ]);
  }
  return fence;
}

/** Hai buổi học cùng con, cùng thứ mà khoảng giờ giao nhau → báo trùng. */
async function assertNoOverlap(childId, data, exceptId) {
  const others = await SchoolSession.find({ childId, _id: { $ne: exceptId }, isDemo: false });
  for (const o of others) {
    const sharedDays = o.daysOfWeek.filter((d) => data.daysOfWeek.includes(d));
    if (sharedDays.length && data.startTime < o.endTime && o.startTime < data.endTime) {
      const days = sharedDays.map((d) => DAY_NAMES[d]).join(', ');
      throw ApiError.conflict(
        'SESSION_OVERLAP',
        `Trùng giờ với buổi "${o.label || 'học'}" ${o.startTime}–${o.endTime} (${days})`,
        [{ field: 'startTime', message: 'Trùng giờ với buổi học khác' }],
      );
    }
  }
}

export async function list(parentId, childId) {
  await getOwnedChild(parentId, childId);
  const items = await SchoolSession.find({ parentId, childId }).sort({ startTime: 1 });
  const fences = await Geofence.find({ _id: { $in: items.map((s) => s.geofenceId) } });
  const byId = new Map(fences.map((f) => [f._id.toString(), f]));
  return { items: items.map((s) => toSessionDto(s, byId.get(s.geofenceId.toString()))), total: items.length };
}

export async function create(parentId, input) {
  await getOwnedChild(parentId, input.childId);
  const fence = await assertSchoolFence(parentId, input.childId, input.geofenceId);
  await assertNoOverlap(input.childId, input);
  const s = await SchoolSession.create({ ...input, parentId });
  notifyConfigChanged(s.childId);
  return toSessionDto(s, fence);
}

export async function update(parentId, id, input) {
  const s = await getOwned(parentId, id);
  const merged = { ...s.toObject(), ...Object.fromEntries(Object.entries(input).filter(([, v]) => v !== undefined)) };
  if (merged.startTime >= merged.endTime) {
    throw ApiError.badRequest('VALIDATION_ERROR', 'Giờ vào học phải trước giờ tan học', [{ field: 'endTime', message: 'Giờ vào học phải trước giờ tan học' }]);
  }
  const fence = await assertSchoolFence(parentId, s.childId, merged.geofenceId);
  await assertNoOverlap(s.childId, merged, s._id);
  for (const [k, v] of Object.entries(input)) if (v !== undefined) s[k] = v;
  await s.save();
  notifyConfigChanged(s.childId);
  return toSessionDto(s, fence);
}

export async function remove(parentId, id) {
  const s = await getOwned(parentId, id);
  await s.deleteOne();
  notifyConfigChanged(s.childId);
}
