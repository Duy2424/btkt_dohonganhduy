// Route /api/children/*, chỉ phụ huynh. Vị trí của con nằm ở /api/children/:id/locations.
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import { authenticate } from '../../middlewares/authenticate.js';
import { requireRole } from '../../middlewares/requireRole.js';
import locationsRouter from '../locations/locations.routes.js';
import * as c from './children.controller.js';
import * as s from './children.schema.js';

const router = Router();
router.use(authenticate, requireRole('parent'));

router.get('/', validate({ query: s.listChildrenQuery }), asyncHandler(c.list));
router.post('/', validate({ body: s.createChildSchema }), asyncHandler(c.create));
router.get('/:id', validate({ params: s.idParams }), asyncHandler(c.get));
router.patch('/:id', validate({ params: s.idParams, body: s.updateChildSchema }), asyncHandler(c.update));
router.delete('/:id', validate({ params: s.idParams }), asyncHandler(c.remove));
router.post('/:id/pairing-code', validate({ params: s.idParams }), asyncHandler(c.createPairingCode));
router.post('/:id/off-dates', validate({ params: s.idParams, body: s.offDateSchema }), asyncHandler(c.addOffDate));
router.delete('/:id/off-dates', validate({ params: s.idParams, body: s.offDateSchema }), asyncHandler(c.removeOffDate));
router.use('/:id/locations', locationsRouter);

export default router;
