// Gửi push Firebase Cloud Messaging: thông báo cảnh báo tới máy phụ huynh, data message (locate_now,
// config_changed) tới máy con. Thiếu FIREBASE_SERVICE_ACCOUNT_BASE64 → chỉ log cảnh báo và bỏ qua.
import { initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { env } from '../config/env.js';
import { User } from '../models/User.js';
import { logger } from '../utils/logger.js';

let messaging = null;
let warned = false;

function getMessagingClient() {
  if (messaging) return messaging;
  if (!env.FIREBASE_SERVICE_ACCOUNT_BASE64 || env.NODE_ENV === 'test') {
    if (!warned) {
      logger.warn('Chưa cấu hình FIREBASE_SERVICE_ACCOUNT_BASE64 → bỏ qua push (app vẫn nhận qua socket)');
      warned = true;
    }
    return null;
  }
  try {
    const json = Buffer.from(env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf8');
    initializeApp({ credential: cert(JSON.parse(json)) });
    messaging = getMessaging();
  } catch (e) {
    logger.error('Khởi tạo Firebase thất bại:', e.message);
  }
  return messaging;
}

export function isPushEnabled() {
  return Boolean(getMessagingClient());
}

/** Gửi thông báo tới mọi máy của một phụ huynh. level = danger → kênh ưu tiên cao. */
export async function pushToUser(userId, { title, body, level = 'info', data = {} }) {
  const client = getMessagingClient();
  if (!client) return;
  const user = await User.findById(userId).select('fcmTokens');
  if (!user?.fcmTokens?.length) return;

  const res = await client.sendEachForMulticast({
    tokens: user.fcmTokens,
    notification: { title, body },
    data: Object.fromEntries(Object.entries({ ...data, level }).map(([k, v]) => [k, String(v)])),
    android: {
      priority: level === 'danger' ? 'high' : 'normal',
      notification: { channelId: level === 'danger' ? 'conan_danger' : 'conan_default' },
    },
  });
  // Dọn token không còn hợp lệ (app đã gỡ / token đổi)
  const invalid = res.responses
    .map((r, i) => (!r.success && /registration-token-not-registered|invalid-argument/.test(r.error?.code || '') ? user.fcmTokens[i] : null))
    .filter(Boolean);
  if (invalid.length) await User.updateOne({ _id: userId }, { $pull: { fcmTokens: { $in: invalid } } });
}

/** Data message tới máy con: { type: 'locate_now' | 'config_changed' }. */
export async function sendDataToDevice(device, data) {
  const client = getMessagingClient();
  if (!client || !device?.fcmToken) return false;
  try {
    await client.send({ token: device.fcmToken, data, android: { priority: 'high' } });
    return true;
  } catch (e) {
    logger.warn('Gửi data message tới máy con thất bại:', e.message);
    return false;
  }
}
