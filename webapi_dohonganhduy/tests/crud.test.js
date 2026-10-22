// Test API CRUD: hồ sơ con, vùng an toàn, buổi học, lịch khoá, cảnh báo, ticket, quản trị người dùng.
// Kiểm tra cả quyền sở hữu: phụ huynh này không đụng được dữ liệu con của phụ huynh khác.
import { api, bearer, clearDb, loginAs, setupDb, teardownDb } from './helpers.js';
import { Alert } from '../src/models/Alert.js';

beforeAll(setupDb);
afterAll(teardownDb);
beforeEach(clearDb);

const school = { name: 'Trường ABC', type: 'school', center: { lat: 10.7769, lng: 106.7009 }, radiusM: 200 };

async function setupParentWithChild() {
  const parent = await loginAs('parent');
  const auth = bearer(parent.accessToken);
  const child = (await api().post('/api/children').set(auth).send({ name: 'Bé An', birthYear: 2015, schoolName: 'THCS ABC' })).body.data;
  return { parent, auth, child };
}

describe('Hồ sơ con', () => {
  test('CRUD + tìm kiếm + quyền sở hữu', async () => {
    const { auth, child } = await setupParentWithChild();
    expect(child).toMatchObject({ name: 'Bé An', device: null, place: { type: 'unknown' } });

    const list = await api().get('/api/children?search=an').set(auth);
    expect(list.body.data.items).toHaveLength(1);

    const upd = await api().patch(`/api/children/${child.id}`).set(auth).send({ name: 'An Nhiên' });
    expect(upd.body.data.name).toBe('An Nhiên');

    const other = await loginAs('parent');
    expect((await api().get(`/api/children/${child.id}`).set(bearer(other.accessToken))).status).toBe(404);

    expect((await api().delete(`/api/children/${child.id}`).set(auth)).status).toBe(200);
    expect((await api().get(`/api/children/${child.id}`).set(auth)).status).toBe(404);
  });

  test('ngày nghỉ học', async () => {
    const { auth, child } = await setupParentWithChild();
    const add = await api().post(`/api/children/${child.id}/off-dates`).set(auth).send({ date: '2026-10-21' });
    expect(add.body.data.schoolOffDates).toEqual(['2026-10-21']);
    const del = await api().delete(`/api/children/${child.id}/off-dates`).set(auth).send({ date: '2026-10-21' });
    expect(del.body.data.schoolOffDates).toEqual([]);
  });
});

describe('Vùng an toàn + buổi học', () => {
  test('bán kính ngoài 50–1000 m bị từ chối', async () => {
    const { auth, child } = await setupParentWithChild();
    const res = await api().post('/api/geofences').set(auth).send({ ...school, childId: child.id, radiusM: 20 });
    expect(res.status).toBe(400);
    expect(res.body.error.details[0].field).toBe('radiusM');
  });

  test('buổi học phải gắn vùng trường, không trùng giờ; vùng đang dùng không xoá được', async () => {
    const { auth, child } = await setupParentWithChild();
    const fence = (await api().post('/api/geofences').set(auth).send({ ...school, childId: child.id })).body.data;
    const home = (await api().post('/api/geofences').set(auth).send({ ...school, name: 'Nhà', type: 'home', childId: child.id })).body.data;

    const base = { childId: child.id, daysOfWeek: [1, 2, 3, 4, 5], startTime: '07:00', endTime: '11:00', label: 'Sáng' };
    const wrongFence = await api().post('/api/school-sessions').set(auth).send({ ...base, geofenceId: home.id });
    expect(wrongFence.body.error.code).toBe('NOT_SCHOOL_FENCE');

    const s1 = await api().post('/api/school-sessions').set(auth).send({ ...base, geofenceId: fence.id });
    expect(s1.status).toBe(201);

    const overlap = await api().post('/api/school-sessions').set(auth).send({ ...base, geofenceId: fence.id, daysOfWeek: [3], startTime: '10:30', endTime: '12:00' });
    expect(overlap.status).toBe(409);
    expect(overlap.body.error.code).toBe('SESSION_OVERLAP');

    const afternoon = await api().post('/api/school-sessions').set(auth).send({ ...base, geofenceId: fence.id, startTime: '13:30', endTime: '17:00', label: 'Chiều' });
    expect(afternoon.status).toBe(201);

    const badOrder = await api().patch(`/api/school-sessions/${afternoon.body.data.id}`).set(auth).send({ endTime: '12:00' });
    expect(badOrder.status).toBe(400);

    const delFence = await api().delete(`/api/geofences/${fence.id}`).set(auth);
    expect(delFence.status).toBe(409);
    expect(delFence.body.error.code).toBe('GEOFENCE_IN_USE');

    const list = await api().get(`/api/school-sessions?childId=${child.id}`).set(auth);
    expect(list.body.data.items.map((s) => s.label)).toEqual(['Sáng', 'Chiều']);
  });
});

describe('Lịch khoá máy', () => {
  test('cho phép qua nửa đêm, bật/tắt nhanh', async () => {
    const { auth, child } = await setupParentWithChild();
    const created = await api().post('/api/lock-schedules').set(auth).send({
      childId: child.id,
      name: 'Giờ ngủ',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      startTime: '21:30',
      endTime: '06:30',
      allowedPackages: ['com.android.chrome'],
    });
    expect(created.status).toBe(201);
    const toggled = await api().patch(`/api/lock-schedules/${created.body.data.id}`).set(auth).send({ enabled: false });
    expect(toggled.body.data).toMatchObject({ enabled: false, activeNow: false });

    const same = await api().post('/api/lock-schedules').set(auth).send({ childId: child.id, name: 'Lỗi', daysOfWeek: [1], startTime: '08:00', endTime: '08:00' });
    expect(same.status).toBe(400);
  });
});

describe('Cảnh báo', () => {
  test('lọc chưa đọc, đánh dấu đọc, xoá đã đọc', async () => {
    const { parent, auth, child } = await setupParentWithChild();
    await Alert.create([
      { parentId: parent.user.id, childId: child.id, type: 'sos', level: 'danger', title: 'SOS' },
      { parentId: parent.user.id, childId: child.id, type: 'low_battery', level: 'warning', title: 'Pin yếu' },
    ]);
    const list = await api().get('/api/alerts?unread=true').set(auth);
    expect(list.body.data).toMatchObject({ total: 2, unreadCount: 2 });
    const id = list.body.data.items[0].id;
    await api().patch(`/api/alerts/${id}/read`).set(auth).expect(200);
    expect((await api().get('/api/alerts?unread=true').set(auth)).body.data.total).toBe(1);
    await api().patch('/api/alerts/read-all').set(auth).expect(200);
    const removed = await api().delete('/api/alerts/read').set(auth);
    expect(removed.body.data.deleted).toBe(2);
  });
});

describe('Ticket hỗ trợ', () => {
  test('parent tạo → staff nhận → trả lời → đổi trạng thái; parent chỉ xoá khi còn open', async () => {
    const parent = await loginAs('parent');
    const staff = await loginAs('staff');
    const staff2 = await loginAs('staff');
    const p = bearer(parent.accessToken);
    const s = bearer(staff.accessToken);

    const t = (await api().post('/api/tickets').set(p).send({ subject: 'Không ghép được máy', category: 'device', content: 'Quét QR báo hết hạn liên tục' })).body.data;
    expect(t.status).toBe('open');

    const queue = await api().get('/api/tickets?scope=queue').set(s);
    expect(queue.body.data.counts.queue).toBe(1);

    expect((await api().patch(`/api/tickets/${t.id}`).set(s).send({ status: 'resolved' })).status).toBe(403);
    await api().post(`/api/tickets/${t.id}/claim`).set(s).expect(200);
    expect((await api().post(`/api/tickets/${t.id}/claim`).set(bearer(staff2.accessToken))).status).toBe(409);
    expect((await api().get(`/api/tickets/${t.id}`).set(bearer(staff2.accessToken))).status).toBe(404);

    await api().post(`/api/tickets/${t.id}/messages`).set(s).send({ content: 'Bạn thử tạo mã mới nhé' }).expect(200);
    const back = await api().patch(`/api/tickets/${t.id}`).set(s).send({ status: 'open' });
    expect(back.body.error.code).toBe('INVALID_TRANSITION');
    const resolved = await api().patch(`/api/tickets/${t.id}`).set(s).send({ status: 'resolved' });
    expect(resolved.body.data.messages).toHaveLength(2);

    expect((await api().delete(`/api/tickets/${t.id}`).set(p)).body.error.code).toBe('TICKET_NOT_OPEN');
    const mine = await api().get('/api/tickets?scope=done').set(s);
    expect(mine.body.data.items).toHaveLength(1);
  });
});

describe('Quản trị người dùng', () => {
  test('tạo, tìm kiếm, lọc role, khoá, xoá mềm, không tự xoá mình', async () => {
    const admin = await loginAs('admin');
    const a = bearer(admin.accessToken);
    const created = await api().post('/api/admin/users').set(a).send({
      fullName: 'Nhân Viên Mới', username: 'nv_moi', email: 'nvmoi@example.com', password: 'Matkhau123', role: 'staff',
    });
    expect(created.status).toBe(201);
    const id = created.body.data.id;

    const dup = await api().post('/api/admin/users').set(a).send({
      fullName: 'Trùng', username: 'nv_moi', email: 'khac@example.com', password: 'Matkhau123', role: 'staff',
    });
    expect(dup.body.error.details[0].field).toBe('username');

    const search = await api().get('/api/admin/users?search=nv_moi&role=staff').set(a);
    expect(search.body.data.total).toBe(1);

    const locked = await api().patch(`/api/admin/users/${id}/status`).set(a).send({ status: 'locked' });
    expect(locked.body.data.status).toBe('locked');

    expect((await api().delete(`/api/admin/users/${admin.user.id}`).set(a)).body.error.code).toBe('SELF_DELETE');
    await api().delete(`/api/admin/users/${id}`).set(a).expect(200);
    expect((await api().get(`/api/admin/users/${id}`).set(a)).status).toBe(404);

    const stats = await api().get('/api/admin/stats').set(a);
    expect(stats.body.data.usersByRole.admin).toBe(1);
  });
});
