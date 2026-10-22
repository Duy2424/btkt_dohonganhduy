// Route /api/admin/*, chỉ role admin.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import * as c from './admin.controller.js';
import * as s from './admin.schema.js';

const router = Router();
router.use(authenticate, requireRole('admin'));

router.get('/stats', asyncHandler(c.stats));
router.get('/users', validate({ query: s.listUsersQuery }), asyncHandler(c.listUsers));
router.post('/users', validate({ body: s.createUserSchema }), asyncHandler(c.createUser));
router.get('/users/:id', validate({ params: s.idParams }), asyncHandler(c.getUser));
router.patch('/users/:id', validate({ params: s.idParams, body: s.updateUserSchema }), asyncHandler(c.updateUser));
router.patch('/users/:id/status', validate({ params: s.idParams, body: s.statusSchema }), asyncHandler(c.setStatus));
router.delete('/users/:id', validate({ params: s.idParams }), asyncHandler(c.deleteUser));

export default router;
