// Test luồng máy con: ghép QR (một lần dùng), gửi vị trí, cảnh báo vào/ra vùng, SOS, cấu hình, huỷ ghép → 401.
import { api, bearer, clearDb, loginAs, setupDb, teardownDb } from './helpers.js';
import { PairingCode } from '../src/models/PairingCode.js';

beforeAll(setupDb);
afterAll(teardownDb);
beforeEach(clearDb);

async function pairDevice() {
  const parent = await loginAs('parent');
  const auth = bearer(parent.accessToken);
  const child = (await api().post('/api/children').set(auth).send({ name: 'Bé Bin' })).body.data;
  const pc = (await api().post(`/api/children/${child.id}/pairing-code`).set(auth)).body.data;
  expect(JSON.parse(pc.qrPayload)).toEqual({ t: 'conan-pair', c: pc.code });
  const paired = await api().post('/api/devices/pair').send({ code: pc.code, model: 'Xiaomi Redmi Note 13', androidVersion: '14', appVersion: '1.0.0' });
  expect(paired.status).toBe(201);
  return { parent, auth, child, code: pc.code, device: bearer(paired.body.data.deviceToken) };
}

const at = (minAgo) => new Date(Date.now() - minAgo * 60000).toISOString();

describe('Ghép máy bằng QR', () => {
  test('mã dùng một lần; mã sai / hết hạn báo rõ', async () => {
    const { code } = await pairDevice();
    const again = await api().post('/api/devices/pair').send({ code });
    expect(again.body.error.code).toBe('PAIR_CODE_USED');

    const wrong = await api().post('/api/devices/pair').send({ code: 'x'.repeat(43) });
    expect(wrong.body.error.code).toBe('PAIR_CODE_INVALID');

    await PairingCode.updateMany({}, { $set: { usedAt: null, expiresAt: new Date(Date.now() - 1000) } });
    const expired = await api().post('/api/devices/pair').send({ code });
    expect(expired.body.error.code).toBe('PAIR_CODE_EXPIRED');
  });

  test('máy con không gọi được API phụ huynh và ngược lại', async () => {
    const { auth, device } = await pairDevice();
    expect((await api().get('/api/children').set(device)).status).toBe(403);
    expect((await api().get('/api/devices/me/config').set(auth)).status).toBe(403);
  });
});

describe('Vị trí + cảnh báo', () => {
  test('gửi vị trí gộp → cập nhật lastLocation, báo ra khỏi vùng nhà', async () => {
    const { auth, child, device } = await pairDevice();
    await api().post('/api/geofences').set(auth).send({ childId: child.id, name: 'Nhà', type: 'home', center: { lat: 10.8, lng: 106.65 }, radiusM: 100 });

    await api().post('/api/devices/me/locations').set(device).send({
      points: [
        { lat: 10.8, lng: 106.65, accuracy: 10, battery: 80, recordedAt: at(3) },
        { lat: 10.8001, lng: 106.6501, accuracy: 10, battery: 80, recordedAt: at(2) },
      ],
    }).expect(200);
    await api().post('/api/devices/me/locations').set(device).send({
      points: [{ lat: 10.81, lng: 106.66, accuracy: 10, battery: 12, recordedAt: at(1) }],
    }).expect(200);

    const detail = (await api().get(`/api/children/${child.id}`).set(auth)).body.data;
    expect(detail.lastLocation).toMatchObject({ lat: 10.81, battery: 12 });
    expect(detail.device).toMatchObject({ online: true, batteryLevel: 12 });
    expect(detail.place.type).toBe('outside');

    const alerts = (await api().get('/api/alerts').set(auth)).body.data.items.map((a) => a.type).sort();
    expect(alerts).toEqual(['geofence_exit', 'low_battery']);

    const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });
    const history = await api().get(`/api/children/${child.id}/locations?date=${today}`).set(auth);
    expect(history.body.data.points).toHaveLength(3);
  });

  test('SOS tạo cảnh báo đỏ; cấu hình máy con có lịch khoá', async () => {
    const { auth, child, device } = await pairDevice();
    await api().post('/api/lock-schedules').set(auth).send({ childId: child.id, name: 'Giờ ngủ', daysOfWeek: [1, 2, 3, 4, 5, 6, 7], startTime: '21:30', endTime: '06:30' });
    await api().post('/api/devices/me/sos').set(device).send({ lat: 10.8, lng: 106.65 }).expect(200);
    const alerts = (await api().get('/api/alerts').set(auth)).body.data.items;
    expect(alerts[0]).toMatchObject({ type: 'sos', level: 'danger' });

    const config = (await api().get('/api/devices/me/config').set(device)).body.data;
    expect(config.child.name).toBe('Bé Bin');
    expect(config.lockSchedules).toHaveLength(1);
  });

  test('quyền bị tắt → cảnh báo permission_revoked', async () => {
    const { auth, device } = await pairDevice();
    await api().post('/api/devices/me/permission-status').set(device).send({ permissions: { location: true, usageAccess: true } });
    const res = await api().post('/api/devices/me/permission-status').set(device).send({ permissions: { location: true, usageAccess: false } });
    expect(res.body.data.revoked).toEqual(['usageAccess']);
    const alerts = (await api().get('/api/alerts').set(auth)).body.data.items;
    expect(alerts[0].type).toBe('permission_revoked');
  });
});

describe('Huỷ ghép', () => {
  test('phụ huynh huỷ ghép → máy con nhận 401 DEVICE_UNPAIRED', async () => {
    const { auth, device } = await pairDevice();
    const list = (await api().get('/api/devices').set(auth)).body.data.items;
    expect(list).toHaveLength(1);
    await api().delete(`/api/devices/${list[0].id}`).set(auth).expect(200);
    const res = await api().get('/api/devices/me/config').set(device);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('DEVICE_UNPAIRED');
  });
});
