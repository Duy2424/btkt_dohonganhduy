// Điểm khởi động Web API: tạo HTTP server + Socket.IO, kết nối MongoDB (tự thử lại), bật job Giờ học an toàn.
// Bản production chạy bằng `npm start` trên máy server (cổng 3000, đọc .env).
import http from 'node:http';
import { env } from './config/env.js';
import { connectDb, disconnectDb } from './config/db.js';
import { createApp } from './app.js';
import { initSocket, closeSocket } from './sockets/index.js';
import { startSchoolGuardJob, stopSchoolGuardJob } from './modules/school-guard/school-guard.job.js';
import { logger } from './utils/logger.js';

async function connectWithRetry() {
  for (let attempt = 1; ; attempt += 1) {
    try {
      await connectDb();
      return;
    } catch (e) {
      const wait = Math.min(30, attempt * 5);
      logger.error(`Kết nối MongoDB thất bại (lần ${attempt}): ${e.message}. Thử lại sau ${wait}s`);
      await new Promise((r) => setTimeout(r, wait * 1000));
    }
  }
}

async function main() {
  const app = createApp();
  const server = http.createServer(app);
  initSocket(server);

  server.listen(env.PORT, () => {
    logger.info(`ConAn Web API (${env.NODE_ENV}) đang chạy tại http://localhost:${env.PORT} — docs: /docs`);
  });

  await connectWithRetry();
  startSchoolGuardJob();

  const shutdown = async (signal) => {
    logger.info(`Nhận ${signal}, đang tắt server...`);
    stopSchoolGuardJob();
    await closeSocket();
    server.close();
    await disconnectDb();
    process.exit(0);
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((e) => {
  logger.error('Không khởi động được server:', e);
  process.exit(1);
});
