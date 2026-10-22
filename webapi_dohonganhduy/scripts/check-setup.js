// Kiểm tra .env của máy server trước khi chạy thật: nối được MongoDB Atlas chưa, gửi được mail OTP thật chưa.
// Cách dùng: npm run check:setup -- email.nhan.thu@gmail.com
import mongoose from 'mongoose';
import { env } from '../src/config/env.js';
import { sendOtpEmail } from '../src/services/email.service.js';

const to = process.argv[2];

console.log(`Database: ${env.MONGODB_DB_NAME} · Email: ${env.EMAIL_PROVIDER}`);

try {
  await mongoose.connect(env.MONGODB_URI, { dbName: env.MONGODB_DB_NAME, serverSelectionTimeoutMS: 15000 });
  const collections = await mongoose.connection.db.listCollections().toArray();
  console.log(`✓ Kết nối được MongoDB (${collections.length} collection)`);
} catch (e) {
  console.error(`✗ Không kết nối được MongoDB: ${e.message}`);
  console.error('  Xem lại MONGODB_URI, mật khẩu user DB và Network Access của Atlas.');
} finally {
  await mongoose.disconnect();
}

if (!to) {
  console.log('Bỏ qua thử gửi mail (chưa truyền địa chỉ nhận). Ví dụ: npm run check:setup -- ban@gmail.com');
} else {
  try {
    await sendOtpEmail(to, '123456', 'verify_email', 'Kiểm tra cấu hình');
    console.log(`✓ Đã gửi mail thử tới ${to} (mã 123456). Không thấy thì xem thư mục Spam.`);
  } catch (e) {
    console.error(`✗ Gửi mail thất bại: ${e.message}`);
    console.error('  Xem lại GMAIL_USER, GMAIL_APP_PASSWORD (16 ký tự, không dấu cách).');
  }
}
