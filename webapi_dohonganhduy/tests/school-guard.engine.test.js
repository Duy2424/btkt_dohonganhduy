// Unit test engine "Giờ học an toàn": mỗi tình huống trong bảng SPEC mục 5 có ít nhất một test.
// Giờ trong test là giờ Việt Nam (+07:00); 2026-10-21 là Thứ 4.
import { evaluateSession } from '../src/modules/school-guard/school-guard.engine.js';

const vn = (hhmm, day = '2026-10-21') => new Date(`${day}T${hhmm}:00+07:00`);

const fence = { name: 'Trường THCS ABC', center: { lat: 10.7769, lng: 106.7009 }, radiusM: 150 };
const insidePoint = (hhmm) => ({ lat: 10.7770, lng: 106.7010, accuracy: 10, at: vn(hhmm) });
const outsidePoint = (hhmm) => ({ lat: 10.7850, lng: 106.7100, accuracy: 10, at: vn(hhmm) }); // ~1.3 km
const session = {
  daysOfWeek: [1, 2, 3, 4, 5],
  startTime: '07:00',
  endTime: '11:00',
  graceMinutes: 15,
  outsideToleranceMinutes: 5,
  label: 'Sáng',
};

function run(overrides) {
  return evaluateSession({
    session,
    fence,
    point: null,
    lastSeenAt: vn('07:00'),
    now: vn('08:00'),
    offToday: false,
    state: null,
    sentTypes: [],
    childName: 'Bé An',
    ...overrides,
  });
}

const types = (r) => r.alerts.map((a) => a.type);

describe('Chưa đến trường (not_arrived_school)', () => {
  test('trong thời gian ân hạn 15 phút → chưa báo', () => {
    const r = run({ now: vn('07:10'), point: outsidePoint('07:09'), lastSeenAt: vn('07:09') });
    expect(types(r)).toEqual([]);
  });

  test('quá 07:15 mà vẫn ở ngoài trường → báo mức vàng', () => {
    const r = run({ now: vn('07:20'), point: outsidePoint('07:19'), lastSeenAt: vn('07:19') });
    expect(types(r)).toEqual(['not_arrived_school']);
    expect(r.alerts[0].level).toBe('warning');
  });

  test('đã vào trường lúc 06:50 → không báo', () => {
    const r = run({ now: vn('07:20'), point: insidePoint('06:50'), lastSeenAt: vn('07:19') });
    expect(types(r)).toEqual([]);
    expect(r.state.arrived).toBe(true);
  });
});

describe('Rời trường trong giờ học (left_school_during_class)', () => {
  const arrived = { date: '2026-10-21', arrived: true, outsideSince: null };

  test('ra ngoài chưa đủ 5 phút → chưa báo nhưng ghi nhận mốc ra ngoài', () => {
    const r = run({ now: vn('09:03'), point: outsidePoint('09:00'), lastSeenAt: vn('09:03'), state: arrived });
    expect(types(r)).toEqual([]);
    expect(r.state.outsideSince).toEqual(vn('09:00'));
  });

  test('ở ngoài liên tục ≥ 5 phút → báo đỏ kèm vị trí', () => {
    const state = { ...arrived, outsideSince: vn('09:00') };
    const r = run({ now: vn('09:06'), point: outsidePoint('09:06'), lastSeenAt: vn('09:06'), state });
    expect(types(r)).toEqual(['left_school_during_class']);
    expect(r.alerts[0].level).toBe('danger');
    expect(r.alerts[0].location).toMatchObject({ lat: 10.785, lng: 106.71 });
  });

  test('GPS nhảy nhẹ ra ngoài bán kính nhưng trong sai số → vẫn coi là trong trường', () => {
    // cách tâm ~170 m: > 150 m nhưng < 150 + max(accuracy 40, 30)
    const jitter = { lat: 10.77843, lng: 106.7009, accuracy: 40, at: vn('09:10') };
    const r = run({ now: vn('09:20'), point: jitter, lastSeenAt: vn('09:20'), state: { ...arrived, outsideSince: null } });
    expect(types(r)).toEqual([]);
    expect(r.state.outsideSince).toBeNull();
  });
});

describe('Mất tín hiệu trong giờ học (device_offline_school_hours)', () => {
  test('lastSeenAt cũ hơn 15 phút trong giờ học → báo vàng', () => {
    const r = run({ now: vn('09:30'), point: insidePoint('09:00'), lastSeenAt: vn('09:10') });
    expect(types(r)).toEqual(['device_offline_school_hours']);
  });

  test('vẫn gửi vị trí đều → không báo', () => {
    const r = run({ now: vn('09:30'), point: insidePoint('09:29'), lastSeenAt: vn('09:29') });
    expect(types(r)).toEqual([]);
  });
});

describe('Quay lại trường (returned_to_school)', () => {
  test('đã có cảnh báo đỏ, nay vào lại vùng → báo thông tin', () => {
    const state = { date: '2026-10-21', arrived: true, outsideSince: vn('09:00') };
    const r = run({
      now: vn('09:40'),
      point: insidePoint('09:39'),
      lastSeenAt: vn('09:39'),
      state,
      sentTypes: ['left_school_during_class'],
    });
    expect(types(r)).toEqual(['returned_to_school']);
    expect(r.alerts[0].level).toBe('info');
    expect(r.state.outsideSince).toBeNull();
  });

  test('chưa từng có cảnh báo đỏ → không báo quay lại', () => {
    const r = run({ now: vn('09:40'), point: insidePoint('09:39'), lastSeenAt: vn('09:39') });
    expect(types(r)).toEqual([]);
  });
});

describe('Tan học bình thường', () => {
  test('ra khỏi trường trong 30 phút sau giờ tan → chỉ ghi nhật ký (silent), không báo đỏ', () => {
    const state = { date: '2026-10-21', arrived: true, outsideSince: null };
    const r = run({ now: vn('11:10'), point: outsidePoint('11:08'), lastSeenAt: vn('11:10'), state });
    expect(types(r)).toEqual(['school_dismissed']);
    expect(r.alerts[0].silent).toBe(true);
  });

  test('ngoài khung đánh giá (sau 11:30) → không làm gì', () => {
    const r = run({ now: vn('12:00'), point: outsidePoint('12:00') });
    expect(types(r)).toEqual([]);
  });
});

describe('Ngày không đánh giá', () => {
  test('phụ huynh bấm "Hôm nay con nghỉ học" → bỏ qua', () => {
    const r = run({ now: vn('08:00'), point: outsidePoint('08:00'), offToday: true });
    expect(types(r)).toEqual([]);
  });

  test('Thứ 7 không có trong thời khoá biểu → bỏ qua', () => {
    const r = run({ now: vn('08:00', '2026-10-24'), point: outsidePoint('08:00') });
    expect(types(r)).toEqual([]);
  });

  test('trạng thái của hôm qua được làm mới cho hôm nay', () => {
    const r = run({
      now: vn('07:20'),
      point: outsidePoint('07:19'),
      lastSeenAt: vn('07:19'),
      state: { date: '2026-10-20', arrived: true, outsideSince: null },
    });
    expect(types(r)).toEqual(['not_arrived_school']);
    expect(r.state.date).toBe('2026-10-21');
  });
});
