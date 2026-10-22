# ConAn Web API (webapi_dohonganhduy)

Backend của app ConAn, đồ án Lập trình di động, sinh viên Đỗ Hồng Anh Duy.

- API đang chạy: https://webapi-dohonganhduy.tail7e7968.ts.net
- Tài liệu Swagger: https://webapi-dohonganhduy.tail7e7968.ts.net/docs
- Kiểm tra server: https://webapi-dohonganhduy.tail7e7968.ts.net/health
- App Flutter (frontend): https://github.com/Duy2424/btkt_dohonganhduy

## Công nghệ

Node.js 24, Express 5 (JavaScript ES modules), MongoDB Atlas với Mongoose (database `ConAnDB_DoHongAnhDuy`), JWT kèm refresh token xoay vòng, OTP qua Gmail SMTP, Socket.IO cho vị trí và cảnh báo realtime, zod để kiểm tra dữ liệu, Jest với Supertest và mongodb-memory-server để test.

## Chạy thử

```
npm install
npm test
npm run dev:memory
```

`dev:memory` chạy cổng 4000 với MongoDB in-memory, có sẵn tài khoản `admin01`, `staff01`, `parent01` (mật khẩu `Matkhau123`), mã OTP in ra terminal.

Chạy với database thật: chép `.env.example` thành `.env`, điền `MONGODB_URI`, Gmail App Password và các biến `SEED_*`, rồi:

```
npm run check:setup -- email.nhan.thu@gmail.com
npm run seed
npm start
```

## Lệnh có sẵn

| Lệnh | Việc làm |
|---|---|
| `npm start` | Chạy production, cổng 3000, đọc `.env` |
| `npm run dev` | Chạy dev, cổng 4000, đọc `.env.development` |
| `npm run dev:memory` | Chạy dev với MongoDB in-memory |
| `npm test` | 44 test: auth, JWT, CRUD, ghép QR, máy con, engine Giờ học an toàn |
| `npm run lint` | ESLint |
| `npm run seed` | Tạo tài khoản admin, nhân viên, phụ huynh từ `SEED_*` |
| `npm run seed:demo` | Thêm dữ liệu mẫu cho buổi thuyết trình |
| `npm run simulate` | Giả lập vị trí để demo Giờ học an toàn |
| `npm run check:setup` | Thử kết nối Atlas và gửi mail OTP |

## Cấu trúc

```
src/
  server.js        HTTP server, Socket.IO, job mỗi phút
  app.js           middleware, /health, /docs, các route /api/*
  config/          đọc biến môi trường, kết nối MongoDB
  models/          model Mongoose
  modules/<tên>/   routes, controller, service, schema cho từng chức năng
  middlewares/     xác thực, phân quyền, validate, rate limit, xử lý lỗi
  services/        email, OTP, token, push
  sockets/         xác thực socket và tên event
  docs/openapi.yaml
scripts/           seed, seed-demo, simulate-location, check-setup
tests/             Jest
```

Phản hồi luôn có dạng `{ success: true, data, message? }`, lỗi là `{ success: false, error: { code, message, details? } }`.
