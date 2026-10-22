// Test JWT access token: token có đủ claim (sub, username, role, iss, aud, jti, exp),
// server từ chối token sai server phát hành, sai app nhận, ký bằng secret khác hoặc thiếu các claim này.
import jwt from 'jsonwebtoken';
import { api, bearer, clearDb, loginAs, setupDb, teardownDb } from './helpers.js';

beforeAll(setupDb);
afterAll(teardownDb);
beforeEach(clearDb);

describe('JWT access token', () => {
  test('token chứa id, username, role, server phát hành, app nhận, mã token và hạn dùng 15 phút', async () => {
    const { accessToken, userDoc } = await loginAs('staff');
    const claims = jwt.decode(accessToken);
    expect(claims).toMatchObject({
      sub: userDoc._id.toString(),
      username: userDoc.username,
      role: 'staff',
      iss: 'webapi-dohonganhduy',
      aud: 'conan-app',
    });
    expect(claims.jti).toMatch(/^[0-9a-f-]{36}$/);
    expect(claims.exp - claims.iat).toBe(15 * 60);
  });

  test('token sai issuer, sai audience, sai secret hoặc thiếu iss/aud đều bị từ chối', async () => {
    const { accessToken, userDoc } = await loginAs('parent');
    const ok = await api().get('/api/children').set(bearer(accessToken));
    expect(ok.status).toBe(200);

    const secret = process.env.JWT_ACCESS_SECRET;
    const make = (opts, key = secret) =>
      jwt.sign({ username: userDoc.username, role: 'parent' }, key, {
        subject: userDoc._id.toString(),
        expiresIn: '5m',
        ...opts,
      });
    const forged = [
      make({ issuer: 'server-khac', audience: 'conan-app' }),
      make({ issuer: 'webapi-dohonganhduy', audience: 'app-khac' }),
      make({ issuer: 'webapi-dohonganhduy', audience: 'conan-app' }, 'secret-gia-mao-1234567890'),
      make({}),
    ];
    for (const token of forged) {
      const res = await api().get('/api/children').set(bearer(token));
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('TOKEN_INVALID');
    }
  });
});
