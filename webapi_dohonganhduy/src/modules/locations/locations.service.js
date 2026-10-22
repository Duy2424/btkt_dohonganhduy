// Nghiệp vụ đọc vị trí cho phụ huynh: vị trí mới nhất (fallback khi socket rớt) + lịch sử theo ngày (polyline).
import { Location } from '../../models/Location.js';
import { Device } from '../../models/Device.js';
import { localDayRange } from '../../utils/time.js';
import { getOwnedChild, toDeviceSummary } from '../children/children.service.js';

export async function latest(parentId, childId) {
  const child = await getOwnedChild(parentId, childId);
  const device = await Device.findOne({ childId: child._id, status: 'active' });
  return {
    childId: child._id.toString(),
    lastLocation: child.lastLocation?.lat ? child.lastLocation : null,
    device: toDeviceSummary(device),
  };
}

export async function history(parentId, childId, date) {
  const child = await getOwnedChild(parentId, childId);
  const { from, to } = localDayRange(date);
  const points = await Location.find({ childId: child._id, recordedAt: { $gte: from, $lt: to } })
    .sort({ recordedAt: 1 })
    .limit(3000)
    .select('lat lng accuracy speed battery recordedAt -_id');
  return { childId: child._id.toString(), date, points };
}
