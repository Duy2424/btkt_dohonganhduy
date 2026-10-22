// Route /api/tickets/*: phụ huynh tạo, nhân viên nhận và xử lý, admin xem hết.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import * as c from './tickets.controller.js';
import * as s from './tickets.schema.js';

const router = Router();
router.use(authenticate, requireRole('admin', 'staff', 'parent'));

router.get('/', validate({ query: s.listQuery }), asyncHandler(c.list));
router.post('/', requireRole('parent'), validate({ body: s.createTicketSchema }), asyncHandler(c.create));
router.get('/:id', validate({ params: s.idParams }), asyncHandler(c.get));
router.patch('/:id', requireRole('staff', 'admin'), validate({ params: s.idParams, body: s.updateTicketSchema }), asyncHandler(c.updateStatus));
router.delete('/:id', requireRole('parent', 'admin'), validate({ params: s.idParams }), asyncHandler(c.remove));
router.post('/:id/messages', validate({ params: s.idParams, body: s.messageSchema }), asyncHandler(c.addMessage));
router.post('/:id/claim', requireRole('staff'), validate({ params: s.idParams }), asyncHandler(c.claim));

export default router;
