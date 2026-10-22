// Controller /api/children/:id/locations: vị trí mới nhất và lịch sử theo ngày.
import { ok } from '../../utils/asyncHandler.js';
import * as service from './locations.service.js';

export async function latest(req, res) {
  ok(res, await service.latest(req.auth.userId, req.valid.params.id));
}

export async function history(req, res) {
  ok(res, await service.history(req.auth.userId, req.valid.params.id, req.valid.query.date));
}
