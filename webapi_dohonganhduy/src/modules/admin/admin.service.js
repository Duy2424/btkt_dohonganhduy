// Nghiệp vụ trang quản trị: CRUD người dùng (xoá mềm), khoá/mở, thống kê.
// Admin không xem được vị trí hay dữ liệu của trẻ, thống kê chỉ là con số tổng.
import bcrypt from 'bcryptjs';
import { User } from '../../models/User.js';
import { Device } from '../../models/Device.js';
import { Alert } from '../../models/Alert.js';
import { SupportTicket } from '../../models/SupportTicket.js';
import { ApiError } from '../../utils/ApiError.js';
import { local } from '../../utils/time.js';
import { escapeRegex } from '../common.schema.js';
import { BCRYPT_ROUNDS } from '../auth/auth.service.js';
import { revokeAllForUser } from '../../services/token.service.js';

export async function listUsers({ page, limit, search, role, status }) {
  const filter = {};
  if (role) filter.role = role;
  filter.status = status || { $ne: 'deleted' };
  if (search) {
    const rx = new RegExp(escapeRegex(search), 'i');
    filter.$or = [{ fullName: rx }, { email: rx }, { username: rx }];
  }
  const [items, total] = await Promise.all([
    User.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
    User.countDocuments(filter),
  ]);
  return { items: items.map((u) => u.toPublic()), page, limit, total };
}

export async function getUser(id) {
  const user = await User.findById(id);
  if (!user || user.status === 'deleted') throw ApiError.notFound('Không tìm thấy người dùng');
  return user.toPublic();
}

async function assertUnique({ email, username }, exceptId) {
  const details = [];
  if (email && (await User.exists({ email, _id: { $ne: exceptId } }))) {
    details.push({ field: 'email', message: 'Email đã được sử dụng' });
  }
  if (username && (await User.exists({ username, _id: { $ne: exceptId } }))) {
    details.push({ field: 'username', message: 'Tên đăng nhập đã tồn tại' });
  }
  if (details.length) throw ApiError.conflict('DUPLICATE', details[0].message, details);
}

export async function createUser(input) {
  await assertUnique(input);
  const user = await User.create({
    ...input,
    passwordHash: await bcrypt.hash(input.password, BCRYPT_ROUNDS),
    status: 'active', // admin tạo → không cần xác minh email
  });
  return user.toPublic();
}

export async function updateUser(adminId, id, input) {
  const user = await User.findById(id);
  if (!user || user.status === 'deleted') throw ApiError.notFound('Không tìm thấy người dùng');
  if (input.role && id === adminId && input.role !== 'admin') {
    throw ApiError.badRequest('SELF_ROLE', 'Không thể tự hạ quyền admin của chính mình');
  }
  await assertUnique({ email: input.email }, user._id);
  for (const key of ['fullName', 'email', 'phone', 'role']) {
    if (input[key] !== undefined) user[key] = input[key];
  }
  await user.save();
  return user.toPublic();
}

export async function setStatus(adminId, id, status) {
  if (id === adminId) throw ApiError.badRequest('SELF_LOCK', 'Không thể tự khoá tài khoản của chính mình');
  const user = await User.findById(id);
  if (!user || user.status === 'deleted') throw ApiError.notFound('Không tìm thấy người dùng');
  user.status = status;
  await user.save();
  if (status === 'locked') await revokeAllForUser(user._id);
  return user.toPublic();
}

export async function deleteUser(adminId, id) {
  if (id === adminId) throw ApiError.badRequest('SELF_DELETE', 'Không thể xoá chính mình');
  const user = await User.findById(id);
  if (!user || user.status === 'deleted') throw ApiError.notFound('Không tìm thấy người dùng');
  // Xoá mềm: giữ lịch sử, đổi email/username để có thể đăng ký lại
  const suffix = `.deleted.${Date.now()}`;
  user.status = 'deleted';
  user.email = `${user.email}${suffix}`;
  user.username = `${user.username}${suffix}`;
  user.fcmTokens = [];
  await user.save();
  await revokeAllForUser(user._id);
}

export async function stats() {
  const startOfDay = local().startOf('day').toDate();
  const [byRole, byStatus, onlineDevices, totalDevices, alertsToday, openTickets, inProgressTickets] =
    await Promise.all([
      User.aggregate([{ $match: { status: { $ne: 'deleted' } } }, { $group: { _id: '$role', count: { $sum: 1 } } }]),
      User.aggregate([{ $match: { status: { $ne: 'deleted' } } }, { $group: { _id: '$status', count: { $sum: 1 } } }]),
      Device.countDocuments({ status: 'active', lastSeenAt: { $gte: new Date(Date.now() - 15 * 60 * 1000) } }),
      Device.countDocuments({ status: 'active' }),
      Alert.countDocuments({ createdAt: { $gte: startOfDay } }),
      SupportTicket.countDocuments({ status: 'open' }),
      SupportTicket.countDocuments({ status: 'in_progress' }),
    ]);
  const toMap = (rows) => Object.fromEntries(rows.map((r) => [r._id, r.count]));
  return {
    usersByRole: { admin: 0, staff: 0, parent: 0, ...toMap(byRole) },
    usersByStatus: { pending: 0, active: 0, locked: 0, ...toMap(byStatus) },
    devices: { online15m: onlineDevices, total: totalDevices },
    alertsToday,
    tickets: { open: openTickets, inProgress: inProgressTickets },
  };
}
