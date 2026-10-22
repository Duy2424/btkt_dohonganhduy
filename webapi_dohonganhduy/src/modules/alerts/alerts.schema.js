// Luật kiểm tra (zod) cho API cảnh báo của phụ huynh.
import { z } from 'zod';
import { ALERT_TYPES } from '../../models/Alert.js';
import { objectId, pagination } from '../common.schema.js';

export const listAlertsQuery = pagination.extend({
  childId: objectId.optional(),
  type: z.enum(ALERT_TYPES).optional(),
  unread: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => v === 'true'),
});

export const idParams = z.object({ id: objectId });
