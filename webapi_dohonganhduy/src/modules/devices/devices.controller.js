// Controller /api/devices/*: phần phụ huynh (danh sách, đổi tên, huỷ ghép, định vị ngay) và phần máy con (me/*).
import { ok } from '../../utils/asyncHandler.js';
import * as service from './devices.service.js';
import * as childDevice from './child-device.service.js';

// Phụ huynh
export async function list(req, res) {
  ok(res, await service.list(req.auth.userId));
}

export async function rename(req, res) {
  ok(res, await service.rename(req.auth.userId, req.valid.params.id, req.valid.body.name), 'Đã đổi tên thiết bị');
}

export async function unpair(req, res) {
  await service.unpair(req.auth.userId, req.valid.params.id);
  ok(res, null, 'Đã huỷ ghép thiết bị');
}

export async function locateNow(req, res) {
  ok(res, await service.locateNow(req.auth.userId, req.valid.params.id), 'Đã gửi yêu cầu định vị');
}

export async function childApps(req, res) {
  ok(res, await childDevice.getApps(req.auth.userId, req.valid.params.id));
}

// Máy con
export async function pair(req, res) {
  ok(res, await childDevice.pair(req.valid.body), 'Ghép máy thành công', 201);
}

export async function leave(req, res) {
  ok(res, await service.leaveByChild(req.auth, req.valid.body.password), 'Đã thoát chế độ con');
}

export async function ingestLocations(req, res) {
  ok(res, await childDevice.ingestLocations(req.auth, req.valid.body.points));
}

export async function getConfig(req, res) {
  ok(res, await childDevice.getConfig(req.auth));
}

export async function saveApps(req, res) {
  ok(res, await childDevice.saveApps(req.auth, req.valid.body.apps));
}

export async function sos(req, res) {
  ok(res, await childDevice.sos(req.auth, req.valid.body), 'Đã gửi SOS tới bố mẹ');
}

export async function setFcmToken(req, res) {
  await childDevice.setFcmToken(req.auth, req.valid.body.token);
  ok(res, null);
}

export async function reportPermissions(req, res) {
  ok(res, await childDevice.reportPermissions(req.auth, req.valid.body.permissions));
}
