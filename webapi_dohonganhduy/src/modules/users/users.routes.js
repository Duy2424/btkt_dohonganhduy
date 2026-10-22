// Route /api/users/me/*, cho admin, staff, parent đã đăng nhập.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import * as c from './users.controller.js';
import * as s from './users.schema.js';

const router = Router();
router.use(authenticate, requireRole('admin', 'staff', 'parent'));

router.patch('/me', validate({ body: s.updateMeSchema }), asyncHandler(c.updateMe));
router.patch('/me/password', validate({ body: s.changePasswordSchema }), asyncHandler(c.changePassword));
router.patch('/me/face-login', validate({ body: s.faceLoginSchema }), asyncHandler(c.setFaceLogin));
router.patch('/me/fcm-token', validate({ body: s.fcmTokenSchema }), asyncHandler(c.setFcmToken));

export default router;
