// `npm run seed`: tạo admin, staff và 2 phụ huynh từ các biến SEED_* trong .env. Chạy lại không tạo trùng.
// Seed vào database dev: node --env-file=.env.development scripts/seed.js
import bcrypt from 'bcryptjs';
import { env } from '../src/config/env.js';
import { connectDb, disconnectDb } from '../src/config/db.js';
import { User } from '../src/models/User.js';
import { passwordField } from '../src/modules/auth/auth.schema.js';

// key là phần giữa tên biến: SEED_<key>_USERNAME, SEED_<key>_EMAIL, SEED_<key>_PASSWORD, SEED_<key>_FULLNAME
const ACCOUNTS = [
  { key: 'ADMIN', role: 'admin' },
  { key: 'STAFF', role: 'staff' },
  { key: 'PARENT', role: 'parent' },
  { key: 'PARENT2', role: 'parent' },
];

async function upsert({ key, role }) {
  const prefix = `SEED_${key}_`;
  const username = process.env[`${prefix}USERNAME`];
  const email = process.env[`${prefix}EMAIL`];
  const password = process.env[`${prefix}PASSWORD`];
  const fullName = process.env[`${prefix}FULLNAME`] || role;
  if (!username || !email || !password) {
    console.log(`⏭  Bỏ qua ${key}: thiếu ${prefix}USERNAME / EMAIL / PASSWORD`);
    return;
  }
  const existing = await User.findOne({ $or: [{ username: username.toLowerCase() }, { email: email.toLowerCase() }] });
  if (existing) {
    console.log(`✓  ${role} "${existing.username}" đã có, giữ nguyên`);
    return;
  }
  if (!passwordField.safeParse(password).success) {
    console.log(`⚠  Mật khẩu của "${username}" không đạt luật của app (tối thiểu 8 ký tự, có chữ và số). Vẫn tạo, nhưng đổi mật khẩu trong app phải theo luật.`);
  }
  await User.create({
    username,
    email,
    fullName,
    role,
    status: 'active',
    passwordHash: await bcrypt.hash(password, 10),
  });
  console.log(`＋ Đã tạo ${role} "${username}" (${email})`);
}

await connectDb();
console.log(`Seed vào database: ${env.MONGODB_DB_NAME}`);
for (const account of ACCOUNTS) await upsert(account);
await disconnectDb();
