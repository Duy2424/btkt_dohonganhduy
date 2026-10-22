// Route /api/devices/*: "pair" không cần đăng nhập (dùng mã QR), "me/*" cho máy con, còn lại cho phụ huynh.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import { authLimiter, passwordLimiter } from '../../middlewares/rateLimit.js';
import * as c from './devices.controller.js';
import * as s from './devices.schema.js';

const router = Router();
const child = [authenticate, requireRole('child')];
const parent = [authenticate, requireRole('parent')];

// Máy con
router.post('/pair', authLimiter, validate({ body: s.pairSchema }), asyncHandler(c.pair));
router.post('/me/locations', ...child, validate({ body: s.locationsSchema }), asyncHandler(c.ingestLocations));
router.get('/me/config', ...child, asyncHandler(c.getConfig));
router.post('/me/apps', ...child, validate({ body: s.appsSchema }), asyncHandler(c.saveApps));
router.post('/me/sos', ...child, validate({ body: s.sosSchema }), asyncHandler(c.sos));
router.patch('/me/fcm-token', ...child, validate({ body: s.fcmTokenSchema }), asyncHandler(c.setFcmToken));
router.post('/me/permission-status', ...child, validate({ body: s.permissionSchema }), asyncHandler(c.reportPermissions));
// Giới hạn số lần thử để con không dò được mật khẩu của bố mẹ
router.post('/me/leave', passwordLimiter, ...child, validate({ body: s.leaveSchema }), asyncHandler(c.leave));

// Phụ huynh
router.get('/', ...parent, asyncHandler(c.list));
router.get('/child/:id/apps', ...parent, validate({ params: s.idParams }), asyncHandler(c.childApps));
router.patch('/:id', ...parent, validate({ params: s.idParams, body: s.renameSchema }), asyncHandler(c.rename));
router.delete('/:id', ...parent, validate({ params: s.idParams }), asyncHandler(c.unpair));
router.post('/:id/locate-now', ...parent, validate({ params: s.idParams }), asyncHandler(c.locateNow));

export default router;
