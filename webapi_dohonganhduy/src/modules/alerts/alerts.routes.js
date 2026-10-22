// Route /api/alerts. Chỉ phụ huynh, và chỉ thấy cảnh báo về con của mình.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import * as c from './alerts.controller.js';
import { idParams, listAlertsQuery } from './alerts.schema.js';

const router = Router();
router.use(authenticate, requireRole('parent'));

router.get('/', validate({ query: listAlertsQuery }), asyncHandler(c.list));
router.patch('/read-all', asyncHandler(c.markAllRead));
router.delete('/read', asyncHandler(c.removeRead));
router.patch('/:id/read', validate({ params: idParams }), asyncHandler(c.markRead));
router.delete('/:id', validate({ params: idParams }), asyncHandler(c.remove));

export default router;
