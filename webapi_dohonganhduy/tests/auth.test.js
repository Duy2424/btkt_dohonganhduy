// Test luồng xác thực: đăng ký + xác minh OTP, đăng nhập 2 bước, refresh xoay vòng, đăng nhập khuôn mặt, chặn sai role.
import { api, bearer, clearDb, createUser, lastOtp, loginAs, setupDb, teardownDb } from './helpers.js';
import { Otp } from '../src/models/Otp.js';

beforeAll(setupDb);
afterAll(teardownDb);
beforeEach(clearDb);

const newUser = {
  fullName: 'Đỗ Hồng Anh Duy',
  username: 'Duy_Parent',
  email: 'duy@example.com',
  password: 'Matkhau123',
};

describe('Health', () => {
  test('/health trả tên project, sinh viên, database', async () => {
    const res = await api().get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      status: 'ok',
      project: 'btkt_dohonganhduy',
      student: 'Đỗ Hồng Anh Duy',
      database: 'ConAnDB_DoHongAnhDuy_test',
      db: 'connected',
    });
  });
});

describe('Đăng ký + xác minh email', () => {
  test('đăng ký → pending → nhập OTP → active, username lưu chữ thường', async () => {
    const reg = await api().post('/api/auth/register').send(newUser);
    expect(reg.status).toBe(201);
    expect(reg.body.data.maskedEmail).toBe('d***@example.com');

    const code = lastOtp(newUser.email);
    expect(code).toMatch(/^\d{6}$/);
    const otpDoc = await Otp.findById(reg.body.data.otpSessionId);
    expect(otpDoc.codeHash).not.toContain(code); // chỉ lưu hash

    const pendingLogin = await api().post('/api/auth/login').send({ username: 'duy_parent', password: newUser.password });
    expect(pendingLogin.status).toBe(403);
    expect(pendingLogin.body.error.code).toBe('ACCOUNT_PENDING');

    const verify = await api().post('/api/auth/verify-email').send({ otpSessionId: reg.body.data.otpSessionId, code });
    expect(verify.status).toBe(200);
    expect(verify.body.data.user).toMatchObject({ username: 'duy_parent', status: 'active', role: 'parent' });
  });

  test('trùng email / username báo lỗi đúng ô nhập', async () => {
    await createUser({ username: 'duy_parent', email: 'other@example.com' });
    const res = await api().post('/api/auth/register').send(newUser);
    expect(res.status).toBe(409);
    expect(res.body.error.details).toEqual([{ field: 'username', message: 'Tên đăng nhập đã tồn tại' }]);
  });

  test('mật khẩu yếu bị từ chối với thông báo tiếng Việt', async () => {
    const res = await api().post('/api/auth/register').send({ ...newUser, password: 'abcdefgh' });
    expect(res.status).toBe(400);
    expect(res.body.error.details[0]).toEqual({ field: 'password', message: 'Mật khẩu phải có chữ số' });
  });

  test('OTP sai 5 lần thì bị huỷ; gửi lại trong 60 giây bị chặn', async () => {
    const reg = await api().post('/api/auth/register').send(newUser);
    const { otpSessionId } = reg.body.data;
    const resend = await api().post('/api/auth/resend-otp').send({ otpSessionId });
    expect(resend.status).toBe(429);

    for (let i = 0; i < 4; i += 1) {
      const r = await api().post('/api/auth/verify-email').send({ otpSessionId, code: '000000' === lastOtp(newUser.email) ? '111111' : '000000' });
      expect(r.body.error.code).toBe('OTP_INVALID');
    }
    const last = await api().post('/api/auth/verify-email').send({ otpSessionId, code: lastOtp(newUser.email) === '000000' ? '111111' : '000000' });
    expect(last.body.error.code).toBe('OTP_TOO_MANY_ATTEMPTS');
    const after = await api().post('/api/auth/verify-email').send({ otpSessionId, code: lastOtp(newUser.email) });
    expect(after.body.error.code).toBe('OTP_NOT_FOUND');
  });
});

describe('Đăng nhập 2 bước + token', () => {
  test('sai mật khẩu và sai username đều trả cùng thông báo chung', async () => {
    const { user } = await createUser({ username: 'parent_a' });
    const wrongPass = await api().post('/api/auth/login').send({ username: user.username, password: 'Sai123456' });
    const noUser = await api().post('/api/auth/login').send({ username: 'khong_ton_tai', password: 'Sai123456' });
    expect(wrongPass.status).toBe(401);
    expect(noUser.status).toBe(401);
    expect(wrongPass.body.error.message).toBe('Sai tên đăng nhập hoặc mật khẩu');
    expect(noUser.body.error.message).toBe(wrongPass.body.error.message);
  });

  test('tài khoản bị khoá không đăng nhập được', async () => {
    const { user, password } = await createUser({ username: 'locked_one', status: 'locked' });
    const res = await api().post('/api/auth/login').send({ username: user.username, password });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_LOCKED');
  });

  test('mật khẩu + OTP → token; refresh xoay vòng; dùng lại token cũ bị chặn', async () => {
    const session = await loginAs('parent');
    expect(session.accessToken).toBeTruthy();
    expect(session.user.role).toBe('parent');

    const me = await api().get('/api/auth/me').set(bearer(session.accessToken));
    expect(me.body.data.username).toBe(session.user.username);

    const r1 = await api().post('/api/auth/refresh').send({ refreshToken: session.refreshToken });
    expect(r1.status).toBe(200);
    expect(r1.body.data.refreshToken).not.toBe(session.refreshToken);

    const reuse = await api().post('/api/auth/refresh').send({ refreshToken: session.refreshToken });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.code).toBe('REFRESH_REUSED');
    // Phát hiện dùng lại → thu hồi luôn token mới
    const r2 = await api().post('/api/auth/refresh').send({ refreshToken: r1.body.data.refreshToken });
    expect(r2.status).toBe(401);
  });

  test('logout thu hồi refresh token', async () => {
    const session = await loginAs('parent');
    await api().post('/api/auth/logout').send({ refreshToken: session.refreshToken }).expect(200);
    const res = await api().post('/api/auth/refresh').send({ refreshToken: session.refreshToken });
    expect(res.status).toBe(401);
  });

  test('quên mật khẩu → OTP → đặt lại → đăng nhập bằng mật khẩu mới', async () => {
    const { user } = await createUser({ username: 'forgetful' });
    const fp = await api().post('/api/auth/forgot-password').send({ email: user.email });
    const code = lastOtp(user.email);
    await api()
      .post('/api/auth/reset-password')
      .send({ otpSessionId: fp.body.data.otpSessionId, code, newPassword: 'MatKhauMoi99' })
      .expect(200);
    const login = await api().post('/api/auth/login').send({ username: 'forgetful', password: 'MatKhauMoi99' });
    expect(login.status).toBe(200);
  });
});

describe('Đăng nhập khuôn mặt', () => {
  test('bật trên máy tin cậy → face-login cấp token mới, máy khác bị từ chối', async () => {
    const session = await loginAs('parent', { deviceId: 'phone-1', password: 'Passw0rd!' });
    const noPass = await api()
      .patch('/api/users/me/face-login')
      .set(bearer(session.accessToken))
      .send({ enabled: true, deviceId: 'phone-1' });
    expect(noPass.status).toBe(400);

    const enable = await api()
      .patch('/api/users/me/face-login')
      .set(bearer(session.accessToken))
      .send({ enabled: true, deviceId: 'phone-1', password: 'Passw0rd!' });
    expect(enable.status).toBe(200);
    const { faceToken } = enable.body.data;

    const other = await api().post('/api/auth/face-login').send({ deviceId: 'phone-2', refreshToken: faceToken });
    expect(other.status).toBe(401);

    const ok = await api().post('/api/auth/face-login').send({ deviceId: 'phone-1', refreshToken: faceToken });
    expect(ok.status).toBe(200);
    expect(ok.body.data.accessToken).toBeTruthy();
    expect(ok.body.data.faceToken).not.toBe(faceToken);
  });
});

describe('Phân quyền theo role', () => {
  test('parent không vào được /api/admin, staff không xem được con', async () => {
    const parent = await loginAs('parent');
    const staff = await loginAs('staff');
    const admin = await loginAs('admin');

    expect((await api().get('/api/admin/stats').set(bearer(parent.accessToken))).status).toBe(403);
    expect((await api().get('/api/children').set(bearer(staff.accessToken))).status).toBe(403);
    expect((await api().get('/api/children').set(bearer(admin.accessToken))).status).toBe(403);
    expect((await api().get('/api/admin/stats').set(bearer(admin.accessToken))).status).toBe(200);
    expect((await api().get('/api/children')).status).toBe(401);
  });
});
