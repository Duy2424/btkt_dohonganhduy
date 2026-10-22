// Xử lý giờ theo múi Asia/Ho_Chi_Minh (dayjs + utc + timezone) cho lịch khoá và thời khoá biểu.
// Không bao giờ dùng new Date().getHours(): kết quả phụ thuộc múi giờ của máy chạy server.
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc.js';
import timezone from 'dayjs/plugin/timezone.js';

dayjs.extend(utc);
dayjs.extend(timezone);

const TZ = process.env.APP_TIMEZONE || 'Asia/Ho_Chi_Minh';

/** Thời điểm `date` nhìn theo giờ Việt Nam. */
export function local(date = new Date()) {
  return dayjs(date).tz(TZ);
}

/** "HH:mm" → số phút từ 00:00. */
export function toMinutes(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

/** Số phút từ 00:00 (giờ VN) của thời điểm `date`. */
export function minutesOfDay(date = new Date()) {
  const d = local(date);
  return d.hour() * 60 + d.minute();
}

/** Thứ trong tuần theo quy ước app: 1 = Thứ 2 … 7 = Chủ nhật. */
export function isoWeekday(date = new Date()) {
  const day = local(date).day(); // 0 = CN
  return day === 0 ? 7 : day;
}

/** Ngày "YYYY-MM-DD" theo giờ VN. */
export function localDateKey(date = new Date()) {
  return local(date).format('YYYY-MM-DD');
}

/** Đổi "HH:mm" của ngày `date` (giờ VN) thành Date UTC. */
export function atLocalTime(date, hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  return local(date).hour(h).minute(m).second(0).millisecond(0).toDate();
}

/** Khoảng [00:00, 24:00) của ngày "YYYY-MM-DD" theo giờ VN, trả về Date UTC. */
export function localDayRange(dateKey) {
  const start = dayjs.tz(dateKey, 'YYYY-MM-DD', TZ).startOf('day');
  return { from: start.toDate(), to: start.add(1, 'day').toDate() };
}

/**
 * Lịch (ngày trong tuần + giờ bắt đầu/kết thúc) có đang hiệu lực tại `date` không.
 * Hỗ trợ khung qua nửa đêm, vd 21:30–06:30: phần sau nửa đêm thuộc về ngày bắt đầu hôm trước.
 */
export function isWithinWeeklyWindow({ daysOfWeek, startTime, endTime }, date = new Date()) {
  const now = minutesOfDay(date);
  const start = toMinutes(startTime);
  const end = toMinutes(endTime);
  const today = isoWeekday(date);
  const yesterday = today === 1 ? 7 : today - 1;
  if (start < end) {
    return daysOfWeek.includes(today) && now >= start && now < end;
  }
  // Qua nửa đêm
  if (now >= start) return daysOfWeek.includes(today);
  if (now < end) return daysOfWeek.includes(yesterday);
  return false;
}

export { dayjs };
