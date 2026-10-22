// Route con của /api/children/:id/locations (đã qua authenticate + requireRole('parent') ở children.routes).
import { Router } from 'express';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { validate } from '../../middlewares/validate.js';
import * as c from './locations.controller.js';
import { childParams, historyQuery } from './locations.schema.js';

const router = Router({ mergeParams: true });

router.get('/latest', validate({ params: childParams }), asyncHandler(c.latest));
router.get('/', validate({ params: childParams, query: historyQuery }), asyncHandler(c.history));

export default router;
