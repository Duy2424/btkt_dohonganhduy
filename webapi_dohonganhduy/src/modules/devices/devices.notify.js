// Báo máy con tải lại cấu hình (lịch khoá / thời khoá biểu) qua FCM data message "config_changed".
// Không chặn request: lỗi push chỉ ghi log, máy con vẫn tự làm mới mỗi 15 phút.
import { Device } from '../../models/Device.js';
import { sendDataToDevice } from '../../services/push.service.js';
import { logger } from '../../utils/logger.js';

export function notifyConfigChanged(childId) {
  Device.findOne({ childId, status: 'active' })
    .then((device) => device && sendDataToDevice(device, { type: 'config_changed' }))
    .catch((e) => logger.warn('Gửi config_changed lỗi:', e.message));
}
