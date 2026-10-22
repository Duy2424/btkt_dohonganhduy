// Nghiệp vụ thiết bị phía phụ huynh: danh sách, đổi tên, huỷ ghép, "Định vị ngay".
// Ghép QR + các API của chính máy con nằm ở child-device.service.js.
import { Device } from '../../models/Device.js';
import { Child } from '../../models/Child.js';
import { ApiError } from '../../utils/ApiError.js';
import { emitToParent } from '../../sockets/index.js';
import { EVENTS } from '../../sockets/events.js';
import { sendDataToDevice, isPushEnabled } from '../../services/push.service.js';
import { toDeviceSummary } from '../children/children.service.js';

export function toDeviceDto(device, child) {
  return {
    ...toDeviceSummary(device),
    childId: device.childId.toString(),
    childName: child?.name,
    childColor: child?.avatarColor,
    installedAppsCount: device.installedApps?.length || 0,
    permissions: device.permissions || {},
  };
}

async function getOwned(parentId, id) {
  const device = await Device.findOne({ _id: id, parentId, status: 'active' });
  if (!device) throw ApiError.notFound('Không tìm thấy thiết bị');
  return device;
}

export async function list(parentId) {
  const devices = await Device.find({ parentId, status: 'active' }).sort({ pairedAt: -1 });
  const children = await Child.find({ _id: { $in: devices.map((d) => d.childId) } });
  const byId = new Map(children.map((c) => [c._id.toString(), c]));
  return { items: devices.map((d) => toDeviceDto(d, byId.get(d.childId.toString()))), total: devices.length };
}

export async function rename(parentId, id, name) {
  const device = await getOwned(parentId, id);
  device.name = name;
  await device.save();
  return toDeviceDto(device, await Child.findById(device.childId));
}

/** Huỷ ghép: thu hồi token → lần gọi API tiếp theo của máy con nhận 401 và tự về màn hình ghép. */
export async function unpair(parentId, id) {
  const device = await getOwned(parentId, id);
  device.status = 'unpaired';
  device.tokenHash = null;
  device.simTokenHash = null;
  await device.save();
  await Child.updateOne({ _id: device.childId, deviceId: device._id }, { $set: { deviceId: null } });
  emitToParent(parentId, EVENTS.DEVICE_STATUS, { deviceId: id, childId: device.childId.toString(), status: 'unpaired' });
}

export async function locateNow(parentId, id) {
  const device = await getOwned(parentId, id);
  if (!isPushEnabled()) {
    throw new ApiError(503, 'PUSH_DISABLED', 'Server chưa cấu hình Firebase nên chưa định vị ngay được');
  }
  const sent = await sendDataToDevice(device, { type: 'locate_now' });
  if (!sent) throw new ApiError(503, 'DEVICE_UNREACHABLE', 'Không gửi được yêu cầu tới máy của con');
  return { sent };
}

/** Lấy device còn hoạt động từ req.auth của máy con. */
export async function getSelf(auth) {
  const device = await Device.findOne({ _id: auth.deviceId, status: 'active' });
  if (!device) throw ApiError.unauthorized('DEVICE_UNPAIRED', 'Thiết bị đã bị huỷ ghép');
  return device;
}
