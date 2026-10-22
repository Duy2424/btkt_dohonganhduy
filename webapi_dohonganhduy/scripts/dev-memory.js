// `npm run dev:memory`: chạy Web API với MongoDB in-memory khi chưa có Atlas. Tắt là mất dữ liệu.
// Tự tạo sẵn admin/staff/parent mật khẩu "Matkhau123" để thử app ngay; OTP in ra terminal.
import { MongoMemoryServer } from 'mongodb-memory-server';

const mongo = await MongoMemoryServer.create();
process.env.MONGODB_URI = mongo.getUri();
process.env.MONGODB_DB_NAME ||= 'ConAnDB_DoHongAnhDuy_dev';
process.env.NODE_ENV = 'development';
process.env.EMAIL_PROVIDER = 'console';
process.env.PORT ||= '4000';
process.env.JWT_ACCESS_SECRET ||= 'dev-access-secret-123456789';
process.env.JWT_REFRESH_SECRET ||= 'dev-refresh-secret-123456789';
process.env.OTP_PEPPER ||= 'dev-pepper';

await import('../src/server.js');

const bcrypt = (await import('bcryptjs')).default;
const { User } = await import('../src/models/User.js');
const passwordHash = await bcrypt.hash('Matkhau123', 10);
for (const role of ['admin', 'staff', 'parent']) {
  await User.create({ username: `${role}01`, email: `${role}01@conan.local`, fullName: `Demo ${role}`, role, status: 'active', passwordHash });
}
console.log('🧪 MongoDB in-memory: đã tạo admin01 / staff01 / parent01 — mật khẩu Matkhau123');
