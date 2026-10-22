// Luật kiểm tra (zod) cho API phụ huynh đọc vị trí của con.
import { z } from 'zod';
import { dateKey, objectId } from '../common.schema.js';

export const childParams = z.object({ id: objectId });
export const historyQuery = z.object({ date: dateKey });
