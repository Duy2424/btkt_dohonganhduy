// `npm run seed:demo`: thêm dữ liệu thuyết trình cho tài khoản phụ huynh SEED_PARENT_USERNAME:
// 2 con, vùng "Nhà" + "Trường", thời khoá biểu T2–T6, 2 lịch khoá, vài cảnh báo, vài ticket ở các trạng thái khác nhau.
// Chạy lại: xoá dữ liệu demo cũ của 2 con demo rồi tạo lại (không đụng dữ liệu khác).
import { connectDb, disconnectDb } from '../src/config/db.js';
import { env } from '../src/config/env.js';
import { User } from '../src/models/User.js';
import { Child } from '../src/models/Child.js';
import { Geofence } from '../src/models/Geofence.js';
import { SchoolSession } from '../src/models/SchoolSession.js';
import { LockSchedule } from '../src/models/LockSchedule.js';
import { Alert } from '../src/models/Alert.js';
import { Location } from '../src/models/Location.js';
import { SupportTicket } from '../src/models/SupportTicket.js';

const DEMO_CHILDREN = [
  { name: 'An', birthYear: 2014, schoolName: 'THCS Lê Quý Đôn', avatarColor: '#0EA5E9', home: [10.7860, 106.6950], school: [10.7798, 106.6990] },
  { name: 'Bin', birthYear: 2017, schoolName: 'Tiểu học Nguyễn Bỉnh Khiêm', avatarColor: '#F97316', home: [10.7860, 106.6950], school: [10.7885, 106.7020] },
];

await connectDb();
console.log(`Seed demo vào database: ${env.MONGODB_DB_NAME}`);

const parentUsername = (process.env.SEED_PARENT_USERNAME || 'parent01').toLowerCase();
const parent = await User.findOne({ username: parentUsername, role: 'parent' });
if (!parent) {
  console.error(`❌ Chưa có phụ huynh "${parentUsername}" — chạy npm run seed trước.`);
  process.exit(1);
}
const staff = await User.findOne({ role: 'staff', status: 'active' });

const old = await Child.find({ parentId: parent._id, name: { $in: DEMO_CHILDREN.map((c) => c.name) } });
const oldIds = old.map((c) => c._id);
await Promise.all([
  Geofence.deleteMany({ childId: { $in: oldIds } }),
  SchoolSession.deleteMany({ childId: { $in: oldIds } }),
  LockSchedule.deleteMany({ childId: { $in: oldIds } }),
  Alert.deleteMany({ childId: { $in: oldIds } }),
  Location.deleteMany({ childId: { $in: oldIds } }),
  Child.deleteMany({ _id: { $in: oldIds } }),
  SupportTicket.deleteMany({ parentId: parent._id, subject: /\(demo\)$/ }),
]);

const now = Date.now();
for (const [i, c] of DEMO_CHILDREN.entries()) {
  const child = await Child.create({
    parentId: parent._id,
    name: c.name,
    birthYear: c.birthYear,
    schoolName: c.schoolName,
    avatarColor: c.avatarColor,
    lastLocation: { lat: c.school[0], lng: c.school[1], accuracy: 15, battery: 82 - i * 30, at: new Date(now - 4 * 60000) },
  });
  const ids = { parentId: parent._id, childId: child._id };
  await Geofence.create({ ...ids, name: 'Nhà', type: 'home', center: { lat: c.home[0], lng: c.home[1] }, radiusM: 120 });
  const school = await Geofence.create({ ...ids, name: c.schoolName, type: 'school', center: { lat: c.school[0], lng: c.school[1] }, radiusM: 200 });

  await SchoolSession.create([
    { ...ids, geofenceId: school._id, daysOfWeek: [1, 2, 3, 4, 5], startTime: '07:00', endTime: '11:15', label: 'Sáng' },
    { ...ids, geofenceId: school._id, daysOfWeek: [1, 3, 5], startTime: '13:30', endTime: '16:30', label: 'Chiều' },
  ]);
  await LockSchedule.create([
    { ...ids, name: 'Giờ ngủ', daysOfWeek: [1, 2, 3, 4, 5, 6, 7], startTime: '21:30', endTime: '06:30', allowedPackages: [] },
    { ...ids, name: 'Giờ học bài', daysOfWeek: [1, 2, 3, 4, 5], startTime: '19:00', endTime: '21:00', allowedPackages: ['com.google.android.apps.docs'] },
  ]);

  // Một quãng đường đi học để xem lịch sử trên bản đồ
  const path = Array.from({ length: 12 }, (_, k) => ({
    childId: child._id,
    lat: c.home[0] + ((c.school[0] - c.home[0]) * k) / 11,
    lng: c.home[1] + ((c.school[1] - c.home[1]) * k) / 11,
    accuracy: 15,
    battery: 90 - k,
    recordedAt: new Date(now - (60 - k * 4) * 60000),
  }));
  await Location.insertMany(path);

  await Alert.create([
    { ...ids, type: 'geofence_exit', level: 'warning', title: 'Đã rời Nhà', message: `${c.name} vừa ra khỏi vùng "Nhà".`, createdAt: new Date(now - 55 * 60000), readAt: new Date() },
    { ...ids, type: 'geofence_enter', level: 'info', title: `Đã đến ${c.schoolName}`, message: `${c.name} vừa vào vùng "${c.schoolName}".`, createdAt: new Date(now - 15 * 60000) },
  ]);
  if (i === 1) {
    await Alert.create({ ...ids, type: 'low_battery', level: 'warning', title: 'Pin yếu', message: `Điện thoại của ${c.name} còn 14% pin.`, createdAt: new Date(now - 5 * 60000) });
  }
  console.log(`＋ Con "${c.name}" (id: ${child._id}) — 2 vùng, 2 buổi học, 2 lịch khoá, lịch sử vị trí`);
}

const msg = (user, role, content, minAgo) => ({ senderId: user._id, senderRole: role, senderName: user.fullName, content, createdAt: new Date(now - minAgo * 60000) });
await SupportTicket.create([
  { parentId: parent._id, subject: 'Không quét được mã QR (demo)', category: 'device', status: 'open', messages: [msg(parent, 'parent', 'Máy con báo mã QR hết hạn dù vừa tạo.', 120)] },
  ...(staff
    ? [
        { parentId: parent._id, assignedStaffId: staff._id, subject: 'Bản đồ không cập nhật vị trí (demo)', category: 'bug', status: 'in_progress', messages: [msg(parent, 'parent', 'Vị trí của bé đứng yên từ sáng.', 300), msg(staff, 'staff', 'Anh/chị kiểm tra giúp em quyền "Luôn cho phép" vị trí trên máy con nhé.', 280)] },
        { parentId: parent._id, assignedStaffId: staff._id, subject: 'Đổi email đăng nhập (demo)', category: 'account', status: 'resolved', messages: [msg(parent, 'parent', 'Tôi muốn đổi sang email mới.', 2000), msg(staff, 'staff', 'Đã cập nhật email mới cho anh/chị.', 1900)] },
      ]
    : []),
]);
console.log(`＋ Ticket demo${staff ? ' (đã gán cho nhân viên ' + staff.username + ')' : ''}`);

await disconnectDb();
console.log('✓ Xong seed demo. Mô phỏng: npm run simulate -- --child <id của Bin> --scenario leave-during-class --create-demo-session');
