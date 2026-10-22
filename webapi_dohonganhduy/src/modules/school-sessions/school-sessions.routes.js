// Route /api/school-sessions, chỉ phụ huynh.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import * as c from './school-sessions.controller.js';
import * as s from './school-sessions.schema.js';

const router = Router();
router.use(authenticate, requireRole('parent'));

router.get('/', validate({ query: s.listQuery }), asyncHandler(c.list));
router.post('/', validate({ body: s.createSessionSchema }), asyncHandler(c.create));
router.patch('/:id', validate({ params: s.idParams, body: s.updateSessionSchema }), asyncHandler(c.update));
router.delete('/:id', validate({ params: s.idParams }), asyncHandler(c.remove));

export default router;
