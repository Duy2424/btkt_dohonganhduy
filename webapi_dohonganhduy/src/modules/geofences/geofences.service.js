// Nghiệp vụ vùng an toàn: CRUD theo con + kiểm tra vào/ra vùng mỗi khi nhận vị trí mới.
// Không cho xoá / đổi loại vùng trường đang gắn thời khoá biểu.
import { Geofence } from '../../models/Geofence.js';
import { SchoolSession } from '../../models/SchoolSession.js';
import { ApiError } from '../../utils/ApiError.js';
import { isInsideFence, isOutsideFence } from '../../utils/geo.js';
import { getOwnedChild } from '../children/children.service.js';
import { createAlert } from '../alerts/alerts.service.js';

export function toGeofenceDto(g) {
  return {
    id: g._id.toString(),
    childId: g.childId.toString(),
    name: g.name,
    type: g.type,
    center: { lat: g.center.lat, lng: g.center.lng },
    radiusM: g.radiusM,
    notifyEnter: g.notifyEnter,
    notifyExit: g.notifyExit,
    active: g.active,
    createdAt: g.createdAt,
  };
}

async function getOwned(parentId, id) {
  const g = await Geofence.findOne({ _id: id, parentId });
  if (!g) throw ApiError.notFound('Không tìm thấy vùng an toàn');
  return g;
}

export async function list(parentId, childId) {
  await getOwnedChild(parentId, childId);
  const items = await Geofence.find({ parentId, childId }).sort({ createdAt: 1 });
  return { items: items.map(toGeofenceDto), total: items.length };
}

export async function create(parentId, input) {
  await getOwnedChild(parentId, input.childId);
  const g = await Geofence.create({ ...input, parentId });
  return toGeofenceDto(g);
}

export async function update(parentId, id, input) {
  const g = await getOwned(parentId, id);
  if (input.type && input.type !== 'school' && g.type === 'school') {
    if (await SchoolSession.exists({ geofenceId: g._id })) {
      throw ApiError.conflict('GEOFENCE_IN_USE', 'Vùng trường đang gắn với thời khoá biểu, không thể đổi loại');
    }
  }
  for (const [k, v] of Object.entries(input)) if (v !== undefined) g[k] = v;
  if (input.center || input.radiusM) g.lastInside = null; // vùng thay đổi → đánh giá lại từ đầu
  await g.save();
  return toGeofenceDto(g);
}

export async function remove(parentId, id) {
  const g = await getOwned(parentId, id);
  const used = await SchoolSession.countDocuments({ geofenceId: g._id });
  if (used) {
    throw ApiError.conflict(
      'GEOFENCE_IN_USE',
      `Vùng "${g.name}" đang gắn với ${used} buổi học trong thời khoá biểu. Hãy xoá hoặc đổi các buổi học đó trước.`,
    );
  }
  await g.deleteOne();
}

/**
 * Kiểm tra vào/ra vùng khi có vị trí mới. Có "vùng đệm" chống GPS nhảy:
 * vào vùng khi ≤ bán kính; chỉ tính là ra khi > bán kính + max(accuracy, 30 m).
 * Vùng trường đã gắn thời khoá biểu thì để engine Giờ học an toàn lo (tránh báo trùng).
 */
export async function checkTransitions(child, point) {
  const fences = await Geofence.find({ childId: child._id, active: true });
  const guarded = new Set(
    (await SchoolSession.distinct('geofenceId', { childId: child._id, active: true })).map(String),
  );
  for (const fence of fences) {
    let inside = fence.lastInside;
    if (isInsideFence(point, fence)) inside = true;
    else if (isOutsideFence(point, fence)) inside = false;
    if (inside === fence.lastInside) continue;

    const previous = fence.lastInside;
    fence.lastInside = inside;
    await fence.save();
    if (previous === null || guarded.has(fence._id.toString())) continue;

    if (inside && fence.notifyEnter) {
      await createAlert({
        parentId: child.parentId,
        childId: child._id,
        type: 'geofence_enter',
        level: 'info',
        title: `Đã đến ${fence.name}`,
        message: `${child.name} vừa vào vùng "${fence.name}".`,
        location: { lat: point.lat, lng: point.lng, accuracy: point.accuracy },
      });
    } else if (!inside && fence.notifyExit) {
      await createAlert({
        parentId: child.parentId,
        childId: child._id,
        type: 'geofence_exit',
        level: 'warning',
        title: `Đã rời ${fence.name}`,
        message: `${child.name} vừa ra khỏi vùng "${fence.name}".`,
        location: { lat: point.lat, lng: point.lng, accuracy: point.accuracy },
      });
    }
  }
}
