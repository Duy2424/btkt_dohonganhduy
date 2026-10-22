# Tiến độ ConAn (btkt_dohonganhduy, Đỗ Hồng Anh Duy)

Cập nhật 21/10/2026. ✅ xong · 🟡 có code, còn thiếu bước do nhóm tự làm · ⬜ chưa làm

## Phase 0: khung dự án ✅
- [x] applicationId và namespace `com.dohonganhduy.btkt_dohonganhduy`, label `ConAn`, minSdk 24, MainActivity đã chuyển package
- [x] `analysis_options` bỏ qua `webapi_dohonganhduy/**` và `deploy/**`; `.gitignore` có `.env`, node_modules, logs
- [x] `webapi_dohonganhduy/` với các script `dev`, `start`, `test`, `lint`, `seed`, `seed:demo`, `simulate`, `dev:memory`, `check:setup`
- [x] `/health` trả `project`, `student`, `database`
- [x] `git init` (chưa commit)

## Phase 1: backend nền và xác thực ✅
- [x] config kiểm tra bằng zod, db lấy dbName từ env, model User, Otp, RefreshToken
- [x] Đăng ký kèm OTP email, đăng nhập 2 bước, refresh xoay vòng (phát hiện token bị dùng lại), logout, quên và đặt lại mật khẩu, đăng nhập khuôn mặt
- [x] authenticate, requireRole, errorHandler, rate limit, helmet, gửi mail qua gmail, brevo hoặc console
- [x] JWT có đủ claim sub, username, role, iss, aud, jti, exp; server kiểm thuật toán HS256, issuer, audience (theo bài LTDD Tuần 7)
- [x] jest, supertest, mongodb-memory-server: 43/43 test pass, lint sạch

## Phase 2: deploy 🟡
- [x] `deploy/install-service.ps1`, `start-funnel.ps1`, `update.ps1`, `check.ps1` (đã kiểm tra cú pháp)
- [x] `npm run check:setup -- <email>` để thử kết nối Atlas và gửi mail thật trước khi cài service
- [ ] Nhóm điền Atlas URI và Gmail App Password vào `.env`, chạy các script trên máy server (các bước ở README)
- [ ] Thay URL Funnel thật vào `lib/core/config/env.dart`

## Phase 3: mobile nền và giao diện xác thực ✅
- [x] Theme Material 3 xanh ngọc có dark mode, font Be Vietnam Pro, router chuyển hướng theo role, dio kèm refresh và retry, secure storage
- [x] Onboarding, đăng ký, OTP 6 ô có đếm ngược, đăng nhập, quên mật khẩu, tài khoản, shell cho admin, nhân viên, phụ huynh
- [x] Khoá màn hình dọc (manifest và `SystemChrome`)

## Phase 4: CRUD ✅
- [x] Người dùng (admin), hồ sơ con, vùng an toàn, buổi học, lịch khoá, ticket, cảnh báo, thiết bị. Đã chạy thử trên máy thật

## Phase 5: QR, chế độ con, vị trí realtime ✅
- [x] Backend ghép QR, nhận vị trí theo lô, socket, lịch sử (có test)
- [x] Màn QR có đếm ngược, quét QR, dịch vụ nền gửi vị trí, Bản đồ (realtime, lịch sử, Định vị ngay), kiểm tra quyền riêng cho Xiaomi

## Phase 6: đăng nhập khuôn mặt 🟡
- [x] ML Kit kết hợp MobileFaceNet (tflite), kiểm tra chớp mắt, sai 3 lần thì quay về mật khẩu và OTP, token khuôn mặt riêng ở server
- [ ] Đặt `assets/models/mobilefacenet.tflite` (xem README) và chỉnh `FACE_THRESHOLD`

## Phase 7: Giờ học an toàn và push 🟡
- [x] Engine thuần có 15 unit test, job chạy mỗi phút, `npm run simulate`, FCM phía server (bỏ qua nếu thiếu key)
- [ ] Firebase: `google-services.json` và service account. Chưa có thì app dùng socket và thông báo cục bộ

## Phase 8: lịch khoá trên máy con và SOS ✅
- [x] SOS giữ 2 giây, màn hình của con, gửi danh sách app, báo khi quyền bị tắt
- [x] Kotlin native: MethodChannel `conan/native`, LockService đọc UsageStats mỗi giây, LockActivity "Đang trong giờ nghỉ", app luôn được phép (launcher, gọi điện, tin nhắn, đồng hồ), lịch khoá lưu trên máy để mất mạng vẫn khoá

## Phase 9: hoàn thiện 🟡
- [x] `npm run seed:demo`, `docs/demo-script.md`, README có hướng dẫn dựng server từng bước
- [x] `.env` và `.env.development` đã có secret ngẫu nhiên (không commit), chỉ còn thiếu Atlas URI và Gmail
- [x] Bỏ các khung gợi ý và dòng mô tả phụ trên giao diện, gọn lại comment trong code
- [ ] Build APK release với URL Funnel thật và đưa lên GitHub Release

## Kết quả kiểm tra
- Smoke test qua HTTP trên server dev (`npm run dev:memory`): 30/30 kiểm tra đạt cho cả 7 yêu cầu đề bài
- `flutter analyze` sạch, `flutter test` 16/16 (router theo role, validator, render các màn chính, bố cục không vỡ)
- Chạy trên Xiaomi 13T (Android 16, HyperOS 3) qua adb, nối server dev bằng `adb reverse tcp:4000 tcp:4000`: đăng ký và OTP, đăng nhập 2 bước (OTP sai báo "còn 4 lần"), điều hướng 3 role, CRUD con, vùng an toàn, buổi học, lịch khoá, ticket qua lại giữa phụ huynh và nhân viên, admin khoá và mở người dùng, ghép máy bằng QR, GPS thật gửi về server, SOS ra cảnh báo đỏ, khoá máy thật (mở app Máy tính trong giờ khoá thì hiện "Đang trong giờ nghỉ"), huỷ ghép thì máy con tự về màn quét QR, vị trí mới hiện trên máy phụ huynh sau khoảng 1,5 giây
- Lỗi tìm ra khi chạy thật và đã sửa: gõ Telex làm "parent01" thành "pảent01"; theme nút rộng vô hạn làm trắng màn chi tiết con và vỡ hộp thoại; nhà mạng chặn DNS tile.openstreetmap.org (thêm máy chủ dự phòng tile.openstreetmap.de); nút Autostart của MIUI cũ không mở được trên HyperOS 3; huỷ ghép không tắt dịch vụ vị trí và khoá máy; điểm vị trí bị gửi trùng; chữ lỗi bị cắt; danh sách người dùng lệch; "© ©" trên bản đồ
- Bản debug có nút "Nhập mã thủ công" ở màn quét QR (để thử trên một máy) và log API (`adb logcat -s flutter`). Bản release không có hai thứ này
