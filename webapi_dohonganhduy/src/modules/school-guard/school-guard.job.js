// Job node-cron chạy mỗi phút: bắt các tình huống không có vị trí mới (chưa đến trường, mất tín hiệu).
// Mọi trạng thái đọc từ DB nên server có restart giữa chừng cũng không mất gì.
import cron from 'node-cron';
import { logger } from '../../utils/logger.js';
import { evaluateAll } from './school-guard.service.js';

let task = null;
let running = false;

export function startSchoolGuardJob() {
  task = cron.schedule('* * * * *', async () => {
    if (running) return; // lần trước chưa xong thì bỏ qua lượt này
    running = true;
    try {
      const created = await evaluateAll(new Date());
      if (created) logger.info(`Giờ học an toàn: tạo ${created} cảnh báo`);
    } catch (e) {
      logger.error('Job Giờ học an toàn lỗi:', e);
    } finally {
      running = false;
    }
  });
  logger.info('Đã bật job Giờ học an toàn (mỗi phút)');
}

export function stopSchoolGuardJob() {
  task?.stop();
}
