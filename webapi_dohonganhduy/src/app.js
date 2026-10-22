// Express app: middleware bảo mật, /health, Swagger /docs, các route /api/* và xử lý lỗi.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import swaggerUi from 'swagger-ui-express';
import { load as loadYaml } from 'js-yaml';
import { env } from './config/env.js';
import { dbStatus } from './config/db.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';
import authRoutes from './modules/auth/auth.routes.js';
import usersRoutes from './modules/users/users.routes.js';
import adminRoutes from './modules/admin/admin.routes.js';
import childrenRoutes from './modules/children/children.routes.js';
import devicesRoutes from './modules/devices/devices.routes.js';
import geofencesRoutes from './modules/geofences/geofences.routes.js';
import schoolSessionsRoutes from './modules/school-sessions/school-sessions.routes.js';
import lockSchedulesRoutes from './modules/lock-schedules/lock-schedules.routes.js';
import alertsRoutes from './modules/alerts/alerts.routes.js';
import ticketsRoutes from './modules/tickets/tickets.routes.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const openapi = loadYaml(fs.readFileSync(path.join(here, 'docs', 'openapi.yaml'), 'utf8'));

export const PROJECT_INFO = Object.freeze({
  project: 'btkt_dohonganhduy',
  student: 'Đỗ Hồng Anh Duy',
  webapi: 'webapi-dohonganhduy',
});

export function createApp() {
  const app = express();
  app.set('trust proxy', 1); // chạy sau Tailscale Funnel
  app.disable('x-powered-by');

  // Swagger UI đặt trước helmet để CSP mặc định không chặn giao diện tài liệu
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(openapi, { customSiteTitle: 'ConAn Web API — Đỗ Hồng Anh Duy' }));

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  // UptimeRobot gọi mỗi 5 phút. Trả kèm tên cá nhân để chứng minh khi thuyết trình.
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      uptime: Math.round(process.uptime()),
      db: dbStatus(),
      time: new Date().toISOString(),
      ...PROJECT_INFO,
      database: env.MONGODB_DB_NAME,
    });
  });

  app.get('/', (req, res) => res.redirect('/docs'));

  app.use('/api/auth', authRoutes);
  app.use('/api/users', usersRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/children', childrenRoutes);
  app.use('/api/devices', devicesRoutes);
  app.use('/api/geofences', geofencesRoutes);
  app.use('/api/school-sessions', schoolSessionsRoutes);
  app.use('/api/lock-schedules', lockSchedulesRoutes);
  app.use('/api/alerts', alertsRoutes);
  app.use('/api/tickets', ticketsRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
