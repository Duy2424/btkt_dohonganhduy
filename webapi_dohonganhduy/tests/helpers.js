// Tiện ích dùng chung cho test: bật MongoDB in-memory, tạo app, tạo user & đăng nhập nhanh, đọc OTP từ hộp thư console.
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { User } from '../src/models/User.js';
import { consoleOutbox } from '../src/services/email.service.js';

let mongo;

export async function setupDb() {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri(), { dbName: 'ConAnDB_DoHongAnhDuy_test' });
  await Promise.all(Object.values(mongoose.models).map((m) => m.syncIndexes()));
}

export async function teardownDb() {
  await mongoose.disconnect();
  await mongo?.stop();
}

export async function clearDb() {
  await Promise.all(Object.values(mongoose.connection.collections).map((c) => c.deleteMany({})));
  consoleOutbox.length = 0;
}

export const app = createApp();
export const api = () => request(app);

export function lastOtp(email) {
  return [...consoleOutbox].reverse().find((m) => m.to === email)?.code;
}

export async function createUser({ role = 'parent', username, password = 'Passw0rd!', status = 'active', email } = {}) {
  const name = username || `${role}_${Math.random().toString(36).slice(2, 8)}`;
  const user = await User.create({
    username: name,
    email: email || `${name}@test.local`,
    passwordHash: await bcrypt.hash(password, 4),
    fullName: `Người dùng ${name}`,
    role,
    status,
  });
  return { user, password };
}

/** Đăng nhập đủ 2 bước, trả về { accessToken, refreshToken, user }. */
export async function loginAs(role = 'parent', opts = {}) {
  const { user, password } = await createUser({ role, ...opts });
  const step1 = await api()
    .post('/api/auth/login')
    .send({ username: user.username, password, deviceId: opts.deviceId || 'test-device', deviceName: 'Jest' });
  const code = lastOtp(user.email);
  const step2 = await api().post('/api/auth/login/verify-otp').send({ otpSessionId: step1.body.data.otpSessionId, code });
  return { ...step2.body.data, userDoc: user };
}

export const bearer = (token) => ({ Authorization: `Bearer ${token}` });
