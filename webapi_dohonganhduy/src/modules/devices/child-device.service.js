// Nghiệp vụ của chính máy con: ghép QR, gửi vị trí (gộp, gửi bù), lấy cấu hình, danh sách app, SOS, quyền.
// Mỗi lần nhận vị trí: lưu Location, cập nhật lastLocation, đẩy socket cho phụ huynh, kiểm tra vùng & Giờ học an toàn.
import { Device } from '../../models/Device.js';
import { Child } from '../../models/Child.js';
import { User } from '../../models/User.js';
import { Location } from '../../models/Location.js';
import { PairingCode } from '../../models/PairingCode.js';
import { LockSchedule } from '../../models/LockSchedule.js';
import { SchoolSession } from '../../models/SchoolSession.js';
import { ApiError } from '../../utils/ApiError.js';
import { logger } from '../../utils/logger.js';
import { isoWeekday, localDateKey, local } from '../../utils/time.js';
import { emitToParent } from '../../sockets/index.js';
import { EVENTS } from '../../sockets/events.js';
import { generateDeviceToken, hashToken } from '../../services/token.service.js';
import { createAlert } from '../alerts/alerts.service.js';
import { checkTransitions } from '../geofences/geofences.service.js';
import { evaluateChild } from '../school-guard/school-guard.service.js';
import { toLockDto } from '../lock-schedules/lock-schedules.service.js';
import { toDeviceSummary } from '../children/children.service.js';

const LOW_BATTERY = 15;
const PERMISSION_LABELS = {
  location: 'Vị trí',
  locationAlways: 'Vị trí "Luôn cho phép"',
  notification: 'Thông báo',
  usageAccess: 'Truy cập dữ liệu sử dụng',
  overlay: 'Hiển thị trên ứng dụng khác',
  batteryOptimization: 'Không giới hạn pin',
};

export async function pair({ code, model, androidVersion, appVersion }) {
  const codeHash = hashToken(code);
  const now = new Date();
  // Đánh dấu "đã dùng" một cách nguyên tử → 2 máy quét cùng lúc chỉ 1 máy thành công.
  const pc = await PairingCode.findOneAndUpdate(
    { codeHash, usedAt: null, expiresAt: { $gt: now } },
    { $set: { usedAt: now } },
  );
  if (!pc) {
    const existing = await PairingCode.findOne({ codeHash });
    if (!existing) throw ApiError.badRequest('PAIR_CODE_INVALID', 'Mã QR không hợp lệ hoặc đã bị thay bằng mã mới');
    if (existing.usedAt) throw ApiError.badRequest('PAIR_CODE_USED', 'Mã QR này đã được dùng, hãy tạo mã mới');
    throw ApiError.badRequest('PAIR_CODE_EXPIRED', 'Mã QR đã hết hạn, hãy bấm "Tạo mã mới" trên máy phụ huynh');
  }

  const child = await Child.findById(pc.childId);
  if (!child) throw ApiError.badRequest('PAIR_CODE_INVALID', 'Hồ sơ con không còn tồn tại');

  // Mỗi con 1 máy: máy cũ (nếu có) bị huỷ ghép.
  await Device.updateMany({ childId: child._id, status: 'active' }, { $set: { status: 'unpaired', tokenHash: null, simTokenHash: null } });

  const deviceToken = generateDeviceToken();
  const device = await Device.create({
    childId: child._id,
    parentId: pc.parentId,
    name: `Điện thoại của ${child.name}`,
    model,
    androidVersion,
    appVersion,
    tokenHash: hashToken(deviceToken),
    lastSeenAt: now,
  });
  child.deviceId = device._id;
  await child.save();

  emitToParent(pc.parentId, EVENTS.DEVICE_PAIRED, {
    deviceId: device._id.toString(),
    childId: child._id.toString(),
    childName: child.name,
    model,
  });

  const parent = await User.findById(pc.parentId).select('fullName');
  return {
    deviceToken,
    device: { id: device._id.toString(), name: device.name },
    child: { id: child._id.toString(), name: child.name, avatarColor: child.avatarColor },
    parentName: parent?.fullName || '',
  };
}

export async function ingestLocations(auth, points) {
  const device = await Device.findById(auth.deviceId);
  const child = await Child.findById(auth.childId);
  if (!device || !child) throw ApiError.unauthorized('DEVICE_UNPAIRED', 'Thiết bị đã bị huỷ ghép');

  const sorted = [...points].sort((a, b) => a.recordedAt - b.recordedAt);
  await Location.insertMany(sorted.map((p) => ({ ...p, childId: child._id })));

  const latest = sorted[sorted.length - 1];
  const prevBattery = device.batteryLevel;
  device.lastSeenAt = new Date();
  if (latest.battery != null) device.batteryLevel = latest.battery;
  await device.save();

  // Gửi bù điểm cũ không được đè lên vị trí mới hơn
  if (!child.lastLocation?.at || latest.recordedAt >= child.lastLocation.at) {
    child.lastLocation = {
      lat: latest.lat,
      lng: latest.lng,
      accuracy: latest.accuracy ?? null,
      battery: latest.battery ?? device.batteryLevel,
      at: latest.recordedAt,
    };
    await child.save();
  }

  emitToParent(child.parentId, EVENTS.LOCATION_NEW, {
    childId: child._id.toString(),
    lastLocation: child.lastLocation,
    device: toDeviceSummary(device),
  });

  // Phần đánh giá chạy sau, lỗi ở đây không làm mất vị trí đã lưu
  try {
    const point = { ...child.lastLocation.toObject?.() ?? child.lastLocation };
    await checkTransitions(child, point);
    await evaluateChild(child._id, new Date());
    if (latest.battery != null && latest.battery <= LOW_BATTERY && (prevBattery == null || prevBattery > LOW_BATTERY)) {
      await createAlert({
        parentId: child.parentId,
        childId: child._id,
        type: 'low_battery',
        level: 'warning',
        title: 'Pin yếu',
        message: `Điện thoại của ${child.name} còn ${latest.battery}% pin.`,
        dedupeKey: `${child._id}:${localDateKey()}:low_battery:${local().hour()}`,
      });
    }
  } catch (e) {
    logger.error('Đánh giá vị trí lỗi:', e);
  }
  return { accepted: points.length };
}

/** Cấu hình cho máy con: lịch khoá, thời khoá biểu hôm nay, thông tin hiển thị trên màn hình con. */
export async function getConfig(auth) {
  const [child, device, locks, sessions] = await Promise.all([
    Child.findById(auth.childId),
    Device.findById(auth.deviceId),
    LockSchedule.find({ childId: auth.childId, enabled: true }),
    SchoolSession.find({ childId: auth.childId, active: true }).populate('geofenceId', 'name'),
  ]);
  if (!child || !device) throw ApiError.unauthorized('DEVICE_UNPAIRED', 'Thiết bị đã bị huỷ ghép');
  const parent = await User.findById(child.parentId).select('fullName');
  const today = isoWeekday();
  const offToday = child.schoolOffDates.includes(localDateKey());
  return {
    child: { id: child._id.toString(), name: child.name, avatarColor: child.avatarColor },
    device: { id: device._id.toString(), name: device.name },
    parentName: parent?.fullName || '',
    timezone: 'Asia/Ho_Chi_Minh',
    serverTime: new Date(),
    lockSchedules: locks.map((l) => toLockDto(l)),
    schoolSessions: sessions.map((s) => ({
      id: s._id.toString(),
      label: s.label,
      daysOfWeek: s.daysOfWeek,
      startTime: s.startTime,
      endTime: s.endTime,
      schoolName: s.geofenceId?.name || '',
    })),
    todaySessions: offToday
      ? []
      : sessions
          .filter((s) => s.daysOfWeek.includes(today))
          .sort((a, b) => a.startTime.localeCompare(b.startTime))
          .map((s) => ({ label: s.label, startTime: s.startTime, endTime: s.endTime, schoolName: s.geofenceId?.name || '' })),
    offToday,
    // Gọi điện, tin nhắn, báo thức luôn được phép; máy con tự tìm tên gói mặc định trên máy.
    alwaysAllowed: ['dialer', 'sms', 'clock'],
  };
}

export async function saveApps(auth, apps) {
  await Device.updateOne({ _id: auth.deviceId }, { $set: { installedApps: apps } });
  return { saved: apps.length };
}

export async function getApps(parentId, childId) {
  const device = await Device.findOne({ childId, parentId, status: 'active' }).select('installedApps');
  return { items: device?.installedApps || [] };
}

export async function sos(auth, { lat, lng, accuracy }) {
  const child = await Child.findById(auth.childId);
  if (!child) throw ApiError.unauthorized('DEVICE_UNPAIRED', 'Thiết bị đã bị huỷ ghép');
  const location = lat != null && lng != null ? { lat, lng, accuracy: accuracy ?? null } : child.lastLocation;
  await createAlert({
    parentId: child.parentId,
    childId: child._id,
    type: 'sos',
    level: 'danger',
    title: '🆘 SOS — Con cần giúp đỡ!',
    message: `${child.name} vừa bấm nút SOS lúc ${local().format('HH:mm')}. Hãy liên lạc với con ngay.`,
    location: location?.lat != null ? { lat: location.lat, lng: location.lng, accuracy: location.accuracy } : null,
    // Chống bấm liên tục: tối đa 1 SOS / phút
    dedupeKey: `${child._id}:sos:${local().format('YYYY-MM-DDTHH:mm')}`,
  });
  return { sent: true };
}

export async function setFcmToken(auth, token) {
  await Device.updateOne({ _id: auth.deviceId }, { $set: { fcmToken: token } });
}

/** Máy con báo trạng thái quyền; quyền nào từ bật → tắt thì cảnh báo phụ huynh. */
export async function reportPermissions(auth, permissions) {
  const device = await Device.findById(auth.deviceId);
  const child = await Child.findById(auth.childId);
  if (!device || !child) throw ApiError.unauthorized('DEVICE_UNPAIRED', 'Thiết bị đã bị huỷ ghép');
  const previous = device.permissions || {};
  const revoked = Object.keys(permissions).filter((k) => previous[k] === true && permissions[k] === false);
  device.permissions = { ...previous, ...permissions };
  device.markModified('permissions');
  await device.save();
  if (revoked.length) {
    const names = revoked.map((k) => PERMISSION_LABELS[k] || k).join(', ');
    await createAlert({
      parentId: child.parentId,
      childId: child._id,
      type: 'permission_revoked',
      level: 'warning',
      title: 'Quyền trên máy con bị tắt',
      message: `Trên máy của ${child.name}, quyền sau đã bị tắt: ${names}. Một số tính năng có thể không hoạt động.`,
      dedupeKey: `${child._id}:${localDateKey()}:permission:${revoked.sort().join(',')}`,
    });
  }
  return { revoked };
}
