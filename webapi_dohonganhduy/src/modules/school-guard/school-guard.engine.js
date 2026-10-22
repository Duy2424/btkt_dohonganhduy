// Tính năng mới "Giờ học an toàn". Engine là hàm thuần, không đụng DB và không tự đọc giờ hệ thống:
// nhận buổi học + vùng trường + vị trí gần nhất + thời điểm → trả danh sách cảnh báo và trạng thái mới.
// Nhờ vậy test được từng tình huống bằng dữ liệu giả (tests/school-guard.engine.test.js).
import { isOutsideFence } from '../../utils/geo.js';
import { isoWeekday, localDateKey, minutesOfDay, toMinutes, local } from '../../utils/time.js';

export const OFFLINE_MINUTES = 15; // mất tín hiệu > 15 phút trong giờ học
export const DISMISSAL_WINDOW_MINUTES = 30; // ra khỏi trường trong 30 phút sau giờ tan = bình thường
export const EARLY_ARRIVAL_MINUTES = 60; // vào trường sớm tối đa 60 phút trước giờ học vẫn tính "đã đến"

const fmt = (date) => local(date).format('HH:mm');

/**
 * @param {object} p
 * @param {object} p.session  { daysOfWeek, startTime, endTime, graceMinutes, outsideToleranceMinutes, label }
 * @param {object} p.fence    { center: {lat,lng}, radiusM, name }
 * @param {object|null} p.point  vị trí gần nhất { lat, lng, accuracy, at }
 * @param {Date|null} p.lastSeenAt  lần cuối máy con liên lạc server
 * @param {Date} p.now
 * @param {boolean} p.offToday  phụ huynh đã bấm "Hôm nay con nghỉ học"
 * @param {object|null} p.state  trạng thái lưu ở DB { date, arrived, outsideSince }
 * @param {string[]} p.sentTypes  các loại cảnh báo đã gửi trong buổi này hôm nay
 * @param {string} p.childName
 * @returns {{ alerts: object[], state: object }}
 */
export function evaluateSession({ session, fence, point, lastSeenAt, now, offToday, state, sentTypes = [], childName = 'Con' }) {
  const today = localDateKey(now);
  const st = state && state.date === today
    ? { date: today, arrived: Boolean(state.arrived), outsideSince: state.outsideSince ? new Date(state.outsideSince) : null }
    : { date: today, arrived: false, outsideSince: null };
  const alerts = [];
  const result = () => ({ alerts, state: st });

  if (offToday || !session.daysOfWeek.includes(isoWeekday(now))) return result();

  const nowMin = minutesOfDay(now);
  const start = toMinutes(session.startTime);
  const end = toMinutes(session.endTime);
  if (nowMin < start - EARLY_ARRIVAL_MINUTES || nowMin >= end + DISMISSAL_WINDOW_MINUTES) return result();

  const inClass = nowMin >= start && nowMin < end;
  const label = session.label ? `buổi ${session.label.toLowerCase()}` : 'buổi học';
  const sessionText = `${label} ${session.startTime}–${session.endTime}`;

  // Chỉ tin vị trí của hôm nay, trong cửa sổ đánh giá
  const pointUsable =
    point && localDateKey(point.at) === today && minutesOfDay(point.at) >= start - EARLY_ARRIVAL_MINUTES;
  const outside = pointUsable ? isOutsideFence(point, fence) : null; // null = chưa biết
  const where = pointUsable ? { lat: point.lat, lng: point.lng, accuracy: point.accuracy ?? null } : null;

  // Đang ở trong trường
  if (outside === false) {
    if (sentTypes.includes('left_school_during_class') && !sentTypes.includes('returned_to_school') && nowMin < end) {
      alerts.push({
        type: 'returned_to_school',
        level: 'info',
        title: 'Con đã quay lại trường',
        message: `${childName} đã vào lại ${fence.name} lúc ${fmt(point.at)}.`,
        location: where,
      });
    }
    st.arrived = true;
    st.outsideSince = null;
  }

  if (inClass) {
    // 1. Chưa đến trường: quá giờ vào + graceMinutes mà chưa từng vào vùng
    if (!st.arrived && nowMin >= start + session.graceMinutes && outside !== false) {
      alerts.push({
        type: 'not_arrived_school',
        level: 'warning',
        title: 'Con chưa đến trường',
        message: `Đã ${fmt(now)} nhưng ${childName} chưa có mặt ở ${fence.name} (${sessionText}).`,
        location: where,
      });
    }

    // 2. Rời trường giữa giờ học: đã đến rồi, nay ở ngoài liên tục ≥ outsideToleranceMinutes
    if (st.arrived && outside === true) {
      if (!st.outsideSince) st.outsideSince = new Date(point.at);
      const outsideMinutes = (now.getTime() - st.outsideSince.getTime()) / 60000;
      if (outsideMinutes >= session.outsideToleranceMinutes) {
        alerts.push({
          type: 'left_school_during_class',
          level: 'danger',
          title: '⚠️ Con rời trường trong giờ học',
          message: `${childName} đã ở ngoài ${fence.name} từ ${fmt(st.outsideSince)} dù đang trong ${sessionText}.`,
          location: where,
        });
      }
    }

    // 3. Mất tín hiệu trong giờ học
    const silentMinutes = lastSeenAt ? (now.getTime() - new Date(lastSeenAt).getTime()) / 60000 : Infinity;
    if (silentMinutes > OFFLINE_MINUTES && nowMin >= start + OFFLINE_MINUTES) {
      alerts.push({
        type: 'device_offline_school_hours',
        level: 'warning',
        title: 'Mất tín hiệu máy của con',
        message: lastSeenAt
          ? `Máy của ${childName} không gửi vị trí từ ${fmt(lastSeenAt)} (đang trong ${sessionText}).`
          : `Máy của ${childName} chưa gửi vị trí nào trong ${sessionText}.`,
        location: where,
      });
    }
  } else if (nowMin >= end) {
    // 4. Tan học bình thường: chỉ ghi nhật ký, không push
    if (st.arrived && outside === true) {
      alerts.push({
        type: 'school_dismissed',
        level: 'info',
        title: 'Con đã tan học',
        message: `${childName} rời ${fence.name} lúc ${fmt(point.at)} sau ${sessionText}.`,
        location: where,
        silent: true,
      });
    }
    st.outsideSince = null;
  }

  return result();
}
