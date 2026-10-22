# ConAn — App quản lý điện thoại trẻ em (đồ án Lập trình di động)

> Claude Code tự đọc file này mỗi phiên. Đặc tả chi tiết (chức năng, API, database, các phase) nằm ở `docs/SPEC.md` — **đọc SPEC trước khi làm bất kỳ phase nào**.
> "ConAn" = "Con An toàn" (tên tạm, nhóm có thể đổi).

## Bối cảnh

- Đồ án nhóm sinh viên. Thang điểm: CRUD 5.5đ · 3 chức năng nâng cao để thuyết trình 3.5đ (đã chọn: **chia sẻ vị trí**, **QR ghép máy**, **đăng nhập khuôn mặt**) · tính năng mới tự đề xuất 1đ (**Giờ học an toàn** — vùng an toàn theo thời khoá biểu) · giao diện đẹp + cả nhóm chạy được 1đ.
- "Cả nhóm chạy được" nghĩa là: mọi thành viên clone repo, mở thư mục `btkt_dohonganhduy` bằng Android Studio, bấm Run → app nối thẳng vào **server production luôn sống, chạy trên máy Windows của nhóm** (public qua Tailscale Funnel). Không ai khác phải tự chạy backend.
- Cả nhóm phải đọc hiểu code để thuyết trình → ưu tiên code rõ ràng, dễ giải thích hơn code "khéo".

## Tech stack (không tự ý đổi)

| Phần | Công nghệ |
|---|---|
| Mobile | Flutter (Dart), Android là nền tảng chính, Material 3 |
| State | flutter_riverpod — Notifier/AsyncNotifier viết tay, **không dùng codegen/build_runner** |
| Routing | go_router, redirect theo role |
| HTTP | dio + interceptor JWT/refresh + retry |
| Realtime | socket_io_client ↔ Socket.IO |
| Backend | Node.js LTS + Express, **JavaScript ES modules** (không TypeScript) |
| Database | MongoDB Atlas M0 + Mongoose — database `ConAnDB_DoHongAnhDuy` |
| Validation | zod (backend), validator tự viết (mobile, cùng rule) |
| Email OTP | nodemailer + Gmail SMTP (App Password); dự phòng Brevo REST API; local dev in ra console |
| Push | Firebase Cloud Messaging (firebase-admin ở server) |
| Hosting | Máy Windows của nhóm: chạy Web API bằng `npm start` (cổng 3000, đọc `.env`) + Tailscale Funnel cấp URL HTTPS cố định `https://webapi-dohonganhduy.<tailnet>.ts.net`. Nhóm không dùng NSSM, `deploy/install-service.ps1` chỉ để tuỳ chọn |
| Bản đồ | flutter_map + OpenStreetMap (không cần API key) |

## Quy ước đặt tên (BẮT BUỘC có tên cá nhân — yêu cầu của giảng viên)

Sinh viên: **Đỗ Hồng Anh Duy** → tên không dấu dùng trong code: `DoHongAnhDuy` / `dohonganhduy`.

| Thành phần | Tên bắt buộc |
|---|---|
| Project (thư mục gốc, project Flutter đã tạo sẵn bằng Android Studio) | `btkt_dohonganhduy` — giữ nguyên tên package Dart `btkt_dohonganhduy` |
| applicationId / namespace Android | đổi `com.example.btkt_dohonganhduy` → `com.dohonganhduy.btkt_dohonganhduy` (sửa `android/app/build.gradle.kts` và chuyển `MainActivity.kt` sang đúng thư mục package mới) |
| Tên app hiển thị | `ConAn` (label trong `AndroidManifest.xml`) |
| Web API | thư mục `webapi_dohonganhduy/`, `package.json` name `webapi-dohonganhduy`, Swagger title "ConAn Web API — Đỗ Hồng Anh Duy", Windows service `WebAPI_DoHongAnhDuy` |
| URL Web API public | đặt tên máy trong Tailscale là `webapi-dohonganhduy` → `https://webapi-dohonganhduy.<tailnet>.ts.net` |
| Cơ sở dữ liệu | MongoDB Atlas cluster `Cluster-DoHongAnhDuy`, database production `ConAnDB_DoHongAnhDuy`, dev `ConAnDB_DoHongAnhDuy_dev`, test `ConAnDB_DoHongAnhDuy_test` |

- Tên database lấy từ biến `MONGODB_DB_NAME`, truyền vào `mongoose.connect(uri, { dbName })` — không để mặc định `test`.
- `/health` trả thêm `{ project: "btkt_dohonganhduy", student: "Đỗ Hồng Anh Duy", database: "ConAnDB_DoHongAnhDuy" }` để khi thuyết trình chứng minh được tên.
- Màn hình "Giới thiệu" trong app (Cài đặt → Giới thiệu) ghi: tên project, sinh viên thực hiện, URL Web API, tên database đang dùng (lấy từ `/health`).

## Cấu trúc thư mục (bắt buộc giữ)

Thư mục gốc **chính là project Flutter** (mở thẳng bằng Android Studio). Web API nằm trong thư mục con `webapi_dohonganhduy/` — cùng một repo cho cả nhóm.

```
btkt_dohonganhduy/                      # GỐC = project Flutter (Android Studio mở thư mục này)
├── CLAUDE.md
├── README.md                           # hướng dẫn chạy cho cả nhóm (ghi đè README mặc định của Flutter)
├── pubspec.yaml · analysis_options.yaml  # analysis_options loại trừ webapi_dohonganhduy/** và deploy/**
├── .gitignore                          # thêm: webapi_dohonganhduy/node_modules/, **/.env, logs/
├── docs/
│   ├── SPEC.md                         # đặc tả
│   ├── PROGRESS.md                     # checklist tiến độ
│   └── demo-script.md                  # kịch bản thuyết trình (Phase 9)
├── deploy/                             # chạy Web API trên máy Windows: install-service.ps1 · start-funnel.ps1 · update.ps1 · check.ps1
├── webapi_dohonganhduy/                # WEB API (Node.js + Express)
│   ├── package.json
│   ├── .env.example
│   ├── src/
│   │   ├── server.js                   # HTTP server + Socket.IO + job, listen
│   │   ├── app.js                      # Express: middleware, mount routes, /health, /docs
│   │   ├── config/                     # env.js (đọc + kiểm tra biến môi trường), db.js
│   │   ├── models/                     # Mongoose, 1 model / 1 file
│   │   ├── modules/
│   │   │   ├── auth/                   # auth.routes.js · auth.controller.js · auth.service.js · auth.schema.js
│   │   │   ├── users/
│   │   │   ├── admin/                  # thống kê
│   │   │   ├── children/
│   │   │   ├── devices/                # ghép QR, nhận vị trí, config cho máy con, SOS
│   │   │   ├── locations/              # phụ huynh đọc vị trí / lịch sử
│   │   │   ├── geofences/
│   │   │   ├── school-sessions/
│   │   │   ├── lock-schedules/
│   │   │   ├── school-guard/           # TÍNH NĂNG MỚI: engine + job
│   │   │   ├── alerts/
│   │   │   └── tickets/
│   │   ├── middlewares/                # authenticate.js · requireRole.js · validate.js · rateLimit.js · errorHandler.js
│   │   ├── sockets/                    # index.js (xác thực handshake, room) · events.js (hằng tên event)
│   │   ├── services/                   # email.service.js · push.service.js · otp.service.js · token.service.js
│   │   ├── utils/                      # ApiError.js · asyncHandler.js · geo.js · time.js · logger.js
│   │   └── docs/openapi.yaml           # Swagger UI tại /docs
│   ├── scripts/                        # seed.js · seed-demo.js · simulate-location.js
│   └── tests/                          # jest + supertest + mongodb-memory-server
├── assets/                             # fonts/ · images/ · models/mobilefacenet.tflite
├── android/app/src/main/kotlin/com/dohonganhduy/btkt_dohonganhduy/
│   ├── MainActivity.kt
│   └── native/                         # Kotlin: lock service, usage stats, MethodChannel
├── test/                               # test Flutter
├── ios/ · linux/ · macos/ · web/ · windows/   # do Flutter tạo sẵn — không đụng tới (đồ án chỉ làm Android)
└── lib/
    ├── main.dart
    ├── app/
    │   ├── app.dart                    # MaterialApp.router
    │   ├── router.dart                 # go_router + redirect theo role
    │   └── theme/                      # app_theme.dart · app_colors.dart · app_spacing.dart · app_text.dart
    ├── core/
    │   ├── config/                     # env.dart (API_BASE_URL, FACE_THRESHOLD…)
    │   ├── network/                    # dio_client.dart · auth_interceptor.dart · retry_interceptor.dart · api_exception.dart
    │   ├── realtime/                   # socket_service.dart
    │   ├── storage/                    # secure_storage.dart · local_prefs.dart
    │   ├── push/                       # fcm_service.dart · local_notification.dart
    │   ├── platform/                   # native_channel.dart (wrapper MethodChannel)
    │   └── utils/                      # validators.dart · formatters.dart · date_utils.dart
    ├── shared/widgets/                 # app_button, app_text_field, loading_skeleton, empty_view, error_view, confirm_dialog…
    └── features/
        ├── onboarding/                 # chọn "Máy phụ huynh / nhân viên" hoặc "Máy của con"
        ├── auth/                       # đăng ký, xác minh email, đăng nhập, OTP, quên mật khẩu
        ├── face_login/                 # đăng ký + đăng nhập khuôn mặt
        ├── admin/                      # trang quản trị
        ├── staff/                      # dashboard nhân viên
        ├── parent/                     # shell + tab tổng quan của phụ huynh
        ├── children/
        ├── map/
        ├── geofences/
        ├── school_schedule/
        ├── lock_schedules/
        ├── alerts/
        ├── tickets/
        ├── devices/                    # QR ghép máy (phía phụ huynh) + danh sách thiết bị
        └── child_mode/                 # máy con: quét QR, dịch vụ nền, màn hình con, SOS, kiểm tra quyền
```

Mỗi thư mục trong `lib/features/<feature>/` chia 3 phần:
- `data/` — `<x>_api.dart` (gọi dio), `<x>_repository.dart`, `models/` (fromJson/toJson viết tay)
- `state/` — provider / notifier
- `ui/` — `screens/` (1 màn hình = 1 file), `widgets/`

## Quy tắc code

### Chung
- Tên biến/hàm/file tiếng Anh. Comment, thông báo lỗi, text giao diện tiếng Việt.
- Mỗi file mở đầu bằng 1–3 dòng comment tiếng Việt: file này làm gì, thuộc chức năng nào (để nhóm thuyết trình).
- Một file một trách nhiệm. File vượt ~250 dòng thì tách.
- Không hardcode secret, URL, mật khẩu. Secret nằm trong `.env` (không commit), mẫu ở `.env.example`.
- Không thêm thư viện ngoài danh sách trong SPEC khi chưa hỏi. Khi cài: lấy bản stable mới nhất trên pub.dev / npm, kiểm tra tương thích với `flutter --version` / `node -v` hiện tại. Không bịa số phiên bản.

### Backend
- Mỗi module `src/modules/<name>/` gồm: `<name>.routes.js` (route + middleware), `<name>.controller.js` (đọc req → gọi service → trả res, không chứa nghiệp vụ), `<name>.service.js` (nghiệp vụ + truy vấn DB), `<name>.schema.js` (zod).
- Response chuẩn: `{ success: true, data, message? }`; lỗi `{ success: false, error: { code, message, details? } }`. Mọi lỗi đi qua `errorHandler`.
- **Server stateless**: không giữ trạng thái nghiệp vụ trong RAM, không lưu dữ liệu ra file cục bộ — máy server có thể restart bất cứ lúc nào (mất điện, Windows Update). Cần giữ gì → MongoDB.
- **Thời gian**: lưu UTC. Mọi giờ trong lịch khoá / thời khoá biểu là giờ `Asia/Ho_Chi_Minh` → luôn quy đổi qua `utils/time.js` (dayjs + utc + timezone). Cấm dùng `new Date().getHours()` để so lịch — code không được phụ thuộc múi giờ của máy chạy server.
- Phân quyền luôn kiểm ở server (`requireRole`) **và** kiểm quyền sở hữu (phụ huynh chỉ truy cập dữ liệu con của mình).

### Mobile
- Widget dùng chung đặt ở `lib/shared/widgets/`. Màu, cỡ chữ, khoảng cách lấy từ `lib/app/theme/` — không hardcode màu trong màn hình.
- API base URL đọc từ `--dart-define=API_BASE_URL`, mặc định là URL Funnel production (khai báo trong `lib/core/config/env.dart`).
- Mọi màn hình danh sách có đủ 4 trạng thái: loading (skeleton), rỗng, lỗi (nút Thử lại), có dữ liệu; có pull-to-refresh.
- Code Kotlin tự viết chỉ nằm trong `android/app/src/main/kotlin/com/dohonganhduy/btkt_dohonganhduy/native/`, gọi qua MethodChannel, có wrapper Dart ở `lib/core/platform/native_channel.dart`.

## Môi trường của nhóm (chỉnh nếu máy bạn khác)
- Windows 11 + Android Studio. Project nằm ở `C:\Users\anhdu\StudioProjects\btkt_dohonganhduy`. Claude Code chạy **trực tiếp trên Windows** (Claude desktop app, PowerShell / Git Bash) — không dùng WSL.
- Flutter SDK ở `D:\flutter\flutter` (Flutter 3.47.5, Dart 3.13.4), Node.js v24 — gọi thẳng `flutter …`, `node …`, `npm …` trong terminal.
- Project Flutter **đã được tạo sẵn** bằng Android Studio (Dart SDK ^3.13) — không chạy `flutter create` lại, chỉ sửa/bổ sung.
- Không chạy được `flutter` trong terminal hiện tại → **không cài Flutter mới**: ghi rõ lệnh cần chạy để mình chạy trong Android Studio rồi dán kết quả lại.
- **Máy này đồng thời là server production**: bản production chạy bằng `npm start` trong `webapi_dohonganhduy/` (cửa sổ PowerShell để mở), cổng 3000, đọc `webapi_dohonganhduy/.env`. Khi dev dùng `npm run dev` → đọc `.env.development`, cổng **4000**, database `ConAnDB_DoHongAnhDuy_dev` để không đụng production. Tuyệt đối không tự stop/restart server production khi chưa hỏi.
- Máy test: điện thoại Xiaomi thật làm máy con, emulator làm máy phụ huynh. Xiaomi (MIUI/HyperOS) hay tắt app chạy nền → luôn tính đến màn hình hướng dẫn cấp quyền riêng cho Xiaomi (xem SPEC mục 7).

## Cách làm việc
1. Làm đúng theo các phase ở `docs/SPEC.md` mục 11, mỗi lần **một phase**. Không làm lấn sang phase sau.
2. Đầu phase: liệt kê ngắn các file sẽ tạo/sửa rồi làm luôn. Chỉ dừng hỏi khi đặc tả mâu thuẫn hoặc thiếu thông tin bắt buộc.
3. Cuối phase: Web API (`webapi_dohonganhduy/`) chạy `npm test` và `npm run lint`; app (thư mục gốc) chạy `flutter analyze` (và `flutter test` nếu có). Sửa hết lỗi rồi mới báo xong.
4. Cập nhật checklist trong `docs/PROGRESS.md`.
5. Báo cáo cuối phase theo mẫu rồi **dừng chờ**:
   - **Đã làm:** …
   - **File tạo/sửa:** …
   - **Cách tự kiểm tra:** (lệnh / thao tác trên app)
   - **Việc nhóm phải tự làm:** (tạo tài khoản dịch vụ, dán key, cấp quyền trên máy…)
   - **Hạn chế / nợ kỹ thuật:** …
6. Không tự ý đổi cấu trúc thư mục, tech stack, tên endpoint. Muốn đổi → hỏi trước.
7. Không bao giờ commit `.env`, API key, file service account.
