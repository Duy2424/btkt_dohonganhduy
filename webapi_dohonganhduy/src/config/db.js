// Kết nối MongoDB bằng Mongoose. Tên database lấy từ MONGODB_DB_NAME, không để mặc định "test".
import mongoose from 'mongoose';
import { env } from './env.js';
import { logger } from '../utils/logger.js';

// Chỉ báo "mất kết nối" khi đã từng kết nối được và không phải do mình chủ động đóng.
let listening = false;
let connectedOnce = false;
let closing = false;

export async function connectDb(uri = env.MONGODB_URI, dbName = env.MONGODB_DB_NAME) {
  mongoose.set('strictQuery', true);
  if (!listening) {
    listening = true;
    mongoose.connection.on('disconnected', () => {
      if (connectedOnce && !closing) logger.warn('MongoDB mất kết nối');
    });
    mongoose.connection.on('reconnected', () => logger.info('MongoDB đã kết nối lại'));
  }
  await mongoose.connect(uri, { dbName, serverSelectionTimeoutMS: 15000 });
  connectedOnce = true;
  logger.info(`Đã kết nối MongoDB, database: ${dbName}`);
}

export function dbStatus() {
  return mongoose.connection.readyState === 1 ? 'connected' : 'down';
}

export async function disconnectDb() {
  closing = true;
  await mongoose.disconnect();
}
