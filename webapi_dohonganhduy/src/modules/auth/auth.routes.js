// Route /api/auth/*. Endpoint nào cũng validate, endpoint nhạy cảm có thêm rate limit.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import { authLimiter, otpLimiter, passwordLimiter } from '../../middlewares/rateLimit.js';
import * as c from './auth.controller.js';
import * as s from './auth.schema.js';

const router = Router();

router.post('/register', authLimiter, validate({ body: s.registerSchema }), asyncHandler(c.register));
router.post('/verify-email', otpLimiter, validate({ body: s.verifyOtpSchema }), asyncHandler(c.verifyEmail));
router.post('/resend-otp', otpLimiter, validate({ body: s.resendOtpSchema }), asyncHandler(c.resendOtp));
router.post('/login', authLimiter, validate({ body: s.loginSchema }), asyncHandler(c.login));
router.post('/login/verify-otp', otpLimiter, validate({ body: s.verifyOtpSchema }), asyncHandler(c.verifyLoginOtp));
router.post('/face-login', authLimiter, validate({ body: s.faceLoginSchema }), asyncHandler(c.faceLogin));
router.post('/refresh', validate({ body: s.refreshSchema }), asyncHandler(c.refresh));
router.post('/logout', validate({ body: s.refreshSchema }), asyncHandler(c.logout));
router.post('/forgot-password', passwordLimiter, validate({ body: s.forgotPasswordSchema }), asyncHandler(c.forgotPassword));
router.post('/reset-password', otpLimiter, validate({ body: s.resetPasswordSchema }), asyncHandler(c.resetPassword));
router.get('/me', authenticate, requireRole('admin', 'staff', 'parent'), asyncHandler(c.me));

export default router;
