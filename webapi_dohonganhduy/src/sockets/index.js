// Socket.IO: xác thực JWT trong handshake (auth.token), chỉ máy phụ huynh kết nối, tự vào room parent:<userId>.
// Module khác gọi emitToParent() để đẩy vị trí / cảnh báo realtime.
import { Server } from 'socket.io';
import { resolveAuth } from '../middlewares/authenticate.js';
import { logger } from '../utils/logger.js';
import { parentRoom } from './events.js';

let io = null;

export function initSocket(httpServer) {
  io = new Server(httpServer, { cors: { origin: '*' }, pingInterval: 25000, pingTimeout: 20000 });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      const auth = await resolveAuth(token);
      if (auth.role !== 'parent') return next(new Error('FORBIDDEN'));
      socket.data.auth = auth;
      next();
    } catch (e) {
      next(new Error(e.code || 'UNAUTHORIZED'));
    }
  });

  io.on('connection', (socket) => {
    const { userId } = socket.data.auth;
    socket.join(parentRoom(userId));
    logger.info(`Socket phụ huynh ${userId} đã kết nối`);
  });

  return io;
}

/** Gửi event tới mọi máy phụ huynh đang mở app của phụ huynh này. */
export function emitToParent(parentId, event, payload) {
  if (!io) return;
  io.to(parentRoom(parentId.toString())).emit(event, payload);
}

export function closeSocket() {
  return io ? new Promise((resolve) => io.close(() => resolve())) : Promise.resolve();
}
