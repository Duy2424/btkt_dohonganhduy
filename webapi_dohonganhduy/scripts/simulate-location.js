// Demo "Giờ học an toàn" trên lớp:
//   npm run simulate -- --child <childId> --scenario <leave-during-class | arrive-late | normal-day> --create-demo-session
// Script tạo một buổi học tạm phủ giờ hiện tại, rồi gửi chuỗi vị trí giả qua đúng API của máy con
// (POST /api/devices/me/locations) → server đánh giá → phụ huynh nhận cảnh báo ngay. Xong thì xoá buổi học tạm.
// Tuỳ chọn: --api <url> (mặc định http://localhost:PORT), --delay <giây giữa các bước, mặc định 4>.
import { parseArgs } from 'node:util';
import { connectDb, disconnectDb } from '../src/config/db.js';
import { env } from '../src/config/env.js';
import { Child } from '../src/models/Child.js';
import { Device } from '../src/models/Device.js';
import { Geofence } from '../src/models/Geofence.js';
import { SchoolSession } from '../src/models/SchoolSession.js';
import { generateDeviceToken, hashToken } from '../src/services/token.service.js';
import { local, isoWeekday } from '../src/utils/time.js';

const { values: args } = parseArgs({
  options: {
    child: { type: 'string' },
    scenario: { type: 'string', default: 'leave-during-class' },
    'create-demo-session': { type: 'boolean', default: false },
    api: { type: 'string', default: `http://localhost:${env.PORT}` },
    delay: { type: 'string', default: '4' },
  },
});

const SCENARIOS = ['leave-during-class', 'arrive-late', 'normal-day'];
if (!args.child || !SCENARIOS.includes(args.scenario)) {
  console.log('Cách dùng: npm run simulate -- --child <childId> --scenario <leave-during-class|arrive-late|normal-day> --create-demo-session');
  process.exit(1);
}

const sleep = (s) => new Promise((r) => setTimeout(r, s * 1000));
const delay = Number(args.delay);
const minutesAgo = (m) => new Date(Date.now() - m * 60000);
const hhmm = (date) => local(date).format('HH:mm');
const say = (msg) => console.log(`[${local().format('HH:mm:ss')}] ${msg}`);

await connectDb();
const child = await Child.findById(args.child);
if (!child) {
  console.error('❌ Không tìm thấy con với id này (xem trong app: Con → chi tiết, hoặc Swagger GET /api/children)');
  process.exit(1);
}

// 1. Vùng trường: dùng vùng "Trường" có sẵn, chưa có thì tạo vùng tạm
let fence = await Geofence.findOne({ childId: child._id, type: 'school', active: true });
let tempFence = false;
if (!fence) {
  const base = child.lastLocation?.lat ? child.lastLocation : { lat: 10.7769, lng: 106.7009 };
  fence = await Geofence.create({
    parentId: child.parentId,
    childId: child._id,
    name: 'Trường (demo)',
    type: 'school',
    center: { lat: base.lat, lng: base.lng },
    radiusM: 150,
  });
  tempFence = true;
  say(`Tạo vùng trường tạm "${fence.name}"`);
}

// 2. Buổi học tạm phủ giờ hiện tại
const plans = {
  'leave-during-class': { start: minutesAgo(30), end: minutesAgo(-60) },
  'arrive-late': { start: minutesAgo(20), end: minutesAgo(-60) },
  'normal-day': { start: minutesAgo(65), end: minutesAgo(5) },
};
let session = null;
if (args['create-demo-session']) {
  const plan = plans[args.scenario];
  await SchoolSession.deleteMany({ childId: child._id, isDemo: true });
  session = await SchoolSession.create({
    parentId: child.parentId,
    childId: child._id,
    geofenceId: fence._id,
    daysOfWeek: [isoWeekday()],
    startTime: hhmm(plan.start),
    endTime: hhmm(plan.end),
    label: 'Demo',
    graceMinutes: 15,
    outsideToleranceMinutes: 5,
    isDemo: true,
  });
  say(`Tạo buổi học tạm ${session.startTime}–${session.endTime} hôm nay tại "${fence.name}"`);
}

// 3. Token giả lập cho máy con (không đụng token của máy thật)
let device = await Device.findOne({ childId: child._id, status: 'active' });
const token = generateDeviceToken();
if (device) {
  device.simTokenHash = hashToken(token);
  await device.save();
} else {
  device = await Device.create({
    childId: child._id,
    parentId: child.parentId,
    name: 'Máy giả lập (demo)',
    model: 'Simulator',
    tokenHash: hashToken(token),
  });
  child.deviceId = device._id;
  await child.save();
}

const inside = { lat: fence.center.lat + 0.0002, lng: fence.center.lng + 0.0002 };
const outside = { lat: fence.center.lat + 0.012, lng: fence.center.lng + 0.008 }; // ~1.5 km

async function send(point, at, note) {
  const res = await fetch(`${args.api}/api/devices/me/locations`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify({ points: [{ ...point, accuracy: 12, speed: 0, battery: 76, recordedAt: at.toISOString() }] }),
  });
  const body = await res.json();
  say(`${note} → ${res.status} ${body.success ? 'OK' : body.error?.message}`);
  await sleep(delay);
}

say(`Bắt đầu kịch bản "${args.scenario}" cho ${child.name} qua API ${args.api}`);
try {
  if (args.scenario === 'leave-during-class') {
    await send(inside, minutesAgo(12), '📍 Con có mặt ở trường (12 phút trước)');
    await send(inside, minutesAgo(8), '📍 Vẫn trong trường');
    await send(outside, minutesAgo(6), '🚨 Con ra khỏi cổng trường từ 6 phút trước, giữa giờ học (≥ 5 phút) → phụ huynh nhận cảnh báo ĐỎ');
    await send(outside, new Date(), '🚶 Vẫn ở ngoài → không báo lặp lại (chống spam: 1 lần / buổi)');
    await send(inside, new Date(), '🏫 Con quay lại trường → cảnh báo "Con đã quay lại trường"');
  } else if (args.scenario === 'arrive-late') {
    await send(outside, minutesAgo(1), '🏠 Đã quá giờ vào học + 15 phút mà con vẫn ở ngoài → cảnh báo VÀNG "Chưa đến trường"');
  } else {
    await send(inside, minutesAgo(30), '🏫 Con học cả buổi trong trường');
    await send(outside, new Date(), '🎒 Tan học, con ra về → chỉ ghi nhật ký, KHÔNG push');
  }
} finally {
  if (session) {
    await SchoolSession.deleteOne({ _id: session._id });
    say('Đã xoá buổi học tạm');
  }
  if (tempFence) await Geofence.deleteOne({ _id: fence._id });
  await Device.updateOne({ _id: device._id }, { $set: { simTokenHash: null } });
  await disconnectDb();
  say('Xong.');
}
