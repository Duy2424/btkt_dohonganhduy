// Nghiệp vụ hồ sơ con: CRUD (xoá kèm toàn bộ dữ liệu liên quan + huỷ ghép), tạo mã QR ghép máy, ngày nghỉ học.
// getOwnedChild() được module khác dùng để kiểm quyền sở hữu: phụ huynh chỉ đụng được con của mình.
import { Child } from '../../models/Child.js';
import { Device } from '../../models/Device.js';
import { Geofence } from '../../models/Geofence.js';
import { SchoolSession } from '../../models/SchoolSession.js';
import { LockSchedule } from '../../models/LockSchedule.js';
import { Location } from '../../models/Location.js';
import { Alert } from '../../models/Alert.js';
import { PairingCode } from '../../models/PairingCode.js';
import { ApiError } from '../../utils/ApiError.js';
import { distanceMeters } from '../../utils/geo.js';
import { escapeRegex } from '../common.schema.js';
import { generatePairingCode, hashToken } from '../../services/token.service.js';

export const ONLINE_WINDOW_MS = 3 * 60 * 1000; // lastSeenAt < 3 phút → "Trực tuyến"
const PAIRING_TTL_MS = 10 * 60 * 1000;

export async function getOwnedChild(parentId, childId) {
  const child = await Child.findOne({ _id: childId, parentId });
  if (!child) throw ApiError.notFound('Không tìm thấy hồ sơ con');
  return child;
}

/** Con đang ở đâu: trong vùng nào (nhà / trường / khác) hay ngoài vùng. */
function describePlace(child, fences) {
  if (!child.lastLocation?.lat) return { type: 'unknown', name: 'Chưa có vị trí' };
  const inside = fences
    .filter((f) => f.active && distanceMeters(child.lastLocation, f.center) <= f.radiusM)
    .sort((a, b) => a.radiusM - b.radiusM)[0];
  if (!inside) return { type: 'outside', name: 'Ngoài vùng an toàn' };
  const label = { home: 'Ở nhà', school: 'Ở trường' }[inside.type] || `Ở ${inside.name}`;
  return { type: inside.type, name: label, geofenceId: inside._id.toString() };
}

export function toDeviceSummary(device) {
  if (!device || device.status !== 'active') return null;
  return {
    id: device._id.toString(),
    name: device.name,
    model: device.model,
    androidVersion: device.androidVersion,
    appVersion: device.appVersion,
    batteryLevel: device.batteryLevel,
    lastSeenAt: device.lastSeenAt,
    online: Boolean(device.lastSeenAt && Date.now() - device.lastSeenAt.getTime() < ONLINE_WINDOW_MS),
    pairedAt: device.pairedAt,
  };
}

export function toChildDto(child, { device, fences = [], latestAlert } = {}) {
  return {
    id: child._id.toString(),
    name: child.name,
    birthYear: child.birthYear,
    schoolName: child.schoolName,
    avatarColor: child.avatarColor,
    lastLocation: child.lastLocation?.lat ? child.lastLocation : null,
    schoolOffDates: child.schoolOffDates,
    device: toDeviceSummary(device),
    place: describePlace(child, fences),
    latestAlert: latestAlert
      ? { id: latestAlert._id.toString(), type: latestAlert.type, level: latestAlert.level, title: latestAlert.title, createdAt: latestAlert.createdAt }
      : null,
    createdAt: child.createdAt,
  };
}

async function enrich(children) {
  const ids = children.map((c) => c._id);
  const [devices, fences, alerts] = await Promise.all([
    Device.find({ childId: { $in: ids }, status: 'active' }),
    Geofence.find({ childId: { $in: ids }, active: true }),
    Alert.aggregate([
      { $match: { childId: { $in: ids }, silent: false } },
      { $sort: { createdAt: -1 } },
      { $group: { _id: '$childId', doc: { $first: '$$ROOT' } } },
    ]),
  ]);
  const key = (id) => id.toString();
  return children.map((child) =>
    toChildDto(child, {
      device: devices.find((d) => key(d.childId) === key(child._id)),
      fences: fences.filter((f) => key(f.childId) === key(child._id)),
      latestAlert: alerts.find((a) => key(a._id) === key(child._id))?.doc,
    }),
  );
}

export async function list(parentId, { search }) {
  const filter = { parentId };
  if (search) filter.name = new RegExp(escapeRegex(search), 'i');
  const children = await Child.find(filter).sort({ createdAt: 1 });
  return { items: await enrich(children), total: children.length };
}

export async function get(parentId, id) {
  const child = await getOwnedChild(parentId, id);
  const [dto] = await enrich([child]);
  return dto;
}

export async function create(parentId, input) {
  const child = await Child.create({ ...input, parentId });
  const [dto] = await enrich([child]);
  return dto;
}

export async function update(parentId, id, input) {
  const child = await getOwnedChild(parentId, id);
  for (const [k, v] of Object.entries(input)) if (v !== undefined) child[k] = v;
  await child.save();
  const [dto] = await enrich([child]);
  return dto;
}

/** Xoá con + toàn bộ dữ liệu liên quan; thiết bị bị huỷ ghép (token mất hiệu lực ngay). */
export async function remove(parentId, id) {
  const child = await getOwnedChild(parentId, id);
  const childId = child._id;
  await Promise.all([
    Device.updateMany({ childId }, { $set: { status: 'unpaired', tokenHash: null, simTokenHash: null } }),
    Geofence.deleteMany({ childId }),
    SchoolSession.deleteMany({ childId }),
    LockSchedule.deleteMany({ childId }),
    Location.deleteMany({ childId }),
    Alert.deleteMany({ childId }),
    PairingCode.deleteMany({ childId }),
  ]);
  await child.deleteOne();
}

/** Tạo mã ghép QR mới: 32 byte ngẫu nhiên, lưu hash, dùng 1 lần, hết hạn sau 10 phút. */
export async function createPairingCode(parentId, childId) {
  const child = await getOwnedChild(parentId, childId);
  await PairingCode.deleteMany({ childId: child._id, usedAt: null }); // mã cũ chưa dùng hết hiệu lực
  const code = generatePairingCode();
  const expiresAt = new Date(Date.now() + PAIRING_TTL_MS);
  await PairingCode.create({ parentId, childId: child._id, codeHash: hashToken(code), expiresAt });
  return {
    code,
    qrPayload: JSON.stringify({ t: 'conan-pair', c: code }),
    expiresAt,
    ttlSeconds: PAIRING_TTL_MS / 1000,
    child: { id: child._id.toString(), name: child.name },
  };
}

export async function addOffDate(parentId, childId, date) {
  const child = await getOwnedChild(parentId, childId);
  if (!child.schoolOffDates.includes(date)) {
    child.schoolOffDates = [...child.schoolOffDates, date].sort().slice(-60);
    await child.save();
  }
  return { schoolOffDates: child.schoolOffDates };
}

export async function removeOffDate(parentId, childId, date) {
  const child = await getOwnedChild(parentId, childId);
  child.schoolOffDates = child.schoolOffDates.filter((d) => d !== date);
  await child.save();
  return { schoolOffDates: child.schoolOffDates };
}
