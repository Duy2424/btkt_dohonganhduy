# ĐẶC TẢ — ConAn (App quản lý điện thoại trẻ em)

Đặt file này ở `docs/SPEC.md`. Quy tắc code và cấu trúc thư mục xem `CLAUDE.md`.

---

## 1. Tổng quan

Một app Flutter duy nhất (1 file APK cho cả nhóm). Lần đầu mở app chọn:
- **"Máy phụ huynh / nhân viên"** → đăng nhập tài khoản → vào màn hình theo role.
- **"Máy của con"** → không đăng nhập bằng mật khẩu; ghép với tài khoản phụ huynh bằng **quét QR** → chạy chế độ trẻ em.

**Nguyên tắc minh bạch (bắt buộc):** app trên máy con luôn hiện công khai — có icon, có thông báo cố định "ConAn đang chia sẻ vị trí với bố mẹ", màn hình con ghi rõ phụ huynh thấy được gì. Không có chế độ ẩn app, ẩn icon hay chạy lén. Đây là app quản lý gia đình minh bạch, không phải phần mềm theo dõi lén.

**Ngoài phạm vi (không làm):** iOS, web admin riêng, thanh toán, gọi video, chat realtime, Device Owner/kiosk mode, đọc nội dung tin nhắn/cuộc gọi của trẻ.

---

## 2. Vai trò & điều hướng sau đăng nhập (yêu cầu 3)

| Role | Có tài khoản bằng cách | Vào | Được làm | Không được |
|---|---|---|---|---|
| `admin` | `npm run seed` | `/admin` — Trang quản trị | CRUD người dùng, khoá/mở, tạo nhân viên, xem thống kê, xem mọi ticket | xem vị trí / dữ liệu của trẻ |
| `staff` (nhân viên hỗ trợ) | admin tạo | `/staff` — Dashboard nhân viên | xem hàng chờ ticket, nhận ticket, trả lời, đổi trạng thái; dashboard chỉ hiện ticket **của chính nhân viên đó** + hàng chờ | xem vị trí / dữ liệu của trẻ |
| `parent` (khách hàng) | tự đăng ký qua email | `/parent` | quản lý con, thiết bị, bản đồ, lịch khoá, vùng an toàn, thời khoá biểu, cảnh báo, gửi ticket | — |
| `child` (thiết bị) | ghép QR | `/child` | gửi vị trí, nhận lịch khoá, SOS | — |

- go_router `redirect`: chưa đăng nhập → `/login`; đã đăng nhập → home của role; truy cập route của role khác → đẩy về home của mình.
- Client chặn chỉ để UX; **server luôn chặn lại** bằng `requireRole` + kiểm quyền sở hữu.
- Quyền riêng tư theo role là một điểm trình bày: admin/staff không xem được vị trí trẻ.

---

## 3. Xác thực (yêu cầu 1, 2)

### 3.1 Đăng ký qua email
- Trường: `fullName`, `username` (3–20 ký tự, `a-z 0-9 _`, lưu chữ thường), `email`, `password` (≥ 8 ký tự, có chữ và số), `phone` (tuỳ chọn).
- Luồng: `POST /api/auth/register` → user `status = pending` → gửi OTP 6 số tới email (purpose `verify_email`) → màn hình nhập OTP → `POST /api/auth/verify-email` → `status = active` → về màn đăng nhập.
- Đăng ký trùng email/username → báo lỗi rõ ràng tại đúng ô nhập.

### 3.2 Đăng nhập = tên đăng nhập + mật khẩu + OTP
1. `POST /api/auth/login { username, password, deviceId, deviceName }` → đúng thì gửi OTP qua email, trả `{ otpSessionId, maskedEmail: "d***@gmail.com" }`.
2. `POST /api/auth/login/verify-otp { otpSessionId, code }` → `{ accessToken (15 phút), refreshToken (30 ngày), user { id, fullName, role } }`.
3. App lưu token bằng flutter_secure_storage → điều hướng theo role.
- Quên mật khẩu: `POST /api/auth/forgot-password` (gửi OTP) → `POST /api/auth/reset-password`.
- User `pending` đăng nhập → báo "Tài khoản chưa xác minh email" + nút gửi lại OTP.
- User `locked` → báo "Tài khoản đã bị khoá, liên hệ hỗ trợ".

### 3.3 Quy tắc bảo mật
- OTP 6 số, lưu dạng hash (sha256 + `OTP_PEPPER`), hết hạn 5 phút (TTL index), sai quá 5 lần thì huỷ, gửi lại sau 60 giây.
- Thông báo lỗi đăng nhập chung chung ("Sai tên đăng nhập hoặc mật khẩu"), không tiết lộ username có tồn tại hay không.
- Mật khẩu hash bằng bcryptjs. Refresh token lưu dạng hash, xoay vòng mỗi lần refresh, logout thì thu hồi.
- express-rate-limit cho register / login / verify-otp / forgot-password. helmet bật mặc định.
- `EMAIL_PROVIDER=console` (chỉ khi chạy local): in OTP ra terminal thay vì gửi mail. Server **từ chối khởi động** nếu `NODE_ENV=production` mà provider là `console`.
- `services/email.service.js` hỗ trợ 3 provider qua `EMAIL_PROVIDER`: `gmail` (mặc định production — nodemailer + Gmail SMTP cổng 465/587 với App Password, tài khoản Gmail phải bật xác minh 2 bước), `brevo` (dự phòng — `fetch` tới API Brevo qua HTTPS, không cần SDK), `console` (chỉ dev).
- Màn hình OTP nhắc "Không thấy mail? Kiểm tra mục Spam".

---

## 4. Ba chức năng nâng cao (yêu cầu 5)

### 4.1 Ghép máy bằng QR (chức năng e)
- **Phụ huynh:** chọn con → "Ghép điện thoại của con" → `POST /api/children/:id/pairing-code` → server tạo mã ngẫu nhiên 32 byte (base64url), lưu hash, hết hạn 10 phút, dùng một lần → app hiện QR (qr_flutter) chứa `{"t":"conan-pair","c":"<code>"}` + đồng hồ đếm ngược + nút "Tạo mã mới".
- **Máy con:** màn hình quét (mobile_scanner) → `POST /api/devices/pair { code, model, androidVersion, appVersion }` → nhận device token (role `child`) → lưu secure storage → sang màn hình kiểm tra quyền → bật dịch vụ nền.
- Phụ huynh nhận socket event `device:paired` → màn hình chuyển "Ghép thành công 🎉".
- QR sai định dạng / hết hạn / đã dùng → thông báo rõ từng trường hợp.
- **Huỷ ghép:** `DELETE /api/devices/:id` → thu hồi token; máy con gọi API tiếp theo nhận 401 → tự quay về màn hình ghép.

### 4.2 Chia sẻ vị trí realtime (chức năng b)
- **Máy con:** flutter_background_service chạy foreground service (thông báo cố định). geolocator stream `distanceFilter` 25 m + heartbeat mỗi 60 giây. Gửi bằng REST `POST /api/devices/me/locations` (mảng, gửi gộp), kèm `accuracy`, `speed`, `battery` (battery_plus). Mất mạng → xếp hàng trong bộ nhớ máy (tối đa 500 điểm), có mạng gửi bù.
- **Server:** lưu `Location` (TTL 7 ngày), cập nhật `Child.lastLocation` + `Device.lastSeenAt`, emit `location:new` tới room `parent:<parentId>`, chạy engine Giờ học an toàn (mục 5) và kiểm tra vào/ra vùng an toàn.
- **Máy phụ huynh — màn Bản đồ (flutter_map):** marker từng con (avatar màu + tên), vòng tròn các vùng an toàn, nhãn "cập nhật X phút trước", % pin; xem lịch sử theo ngày (polyline, chọn ngày); nút "Định vị ngay" (làm ở Phase 7 khi có FCM: server gửi data message `locate_now` → máy con gửi vị trí ngay).
- Socket.IO: xác thực JWT trong handshake (`auth.token`), tự reconnect. Socket rớt → fallback gọi `GET /api/children/:id/locations/latest` mỗi 30 giây.
- Trạng thái: `lastSeenAt` < 3 phút → "Trực tuyến"; còn lại → "Hoạt động X phút trước".

### 4.3 Đăng nhập bằng khuôn mặt (chức năng a) — cho phụ huynh / nhân viên / admin
- **Thiết kế:** nhận diện chạy hoàn toàn trên máy; **dữ liệu khuôn mặt không gửi lên server** (điểm cộng về quyền riêng tư khi thuyết trình).
- **Bật tính năng** (Cài đặt → "Đăng nhập bằng khuôn mặt", chỉ khi đang đăng nhập, phải nhập lại mật khẩu):
  camera trước → google_mlkit_face_detection (phát hiện + cắt khuôn mặt; bắt buộc đúng 1 mặt, đủ lớn, nhìn thẳng) → MobileFaceNet `.tflite` (tflite_flutter) → embedding → trung bình 5 khung hình, chuẩn hoá L2 → lưu flutter_secure_storage kèm `userId`.
  Server: `PATCH /api/users/me/face-login { enabled: true, deviceId }` → ghi nhận thiết bị tin cậy (không gửi embedding).
- **Đăng nhập:** màn login có nút "Đăng nhập bằng khuôn mặt" (chỉ hiện khi máy đã bật) →
  kiểm tra người thật: yêu cầu chớp mắt (`leftEyeOpenProbability` & `rightEyeOpenProbability` từ > 0.7 xuống < 0.3 rồi lên lại, timeout 8 giây) →
  tính embedding → cosine similarity với mẫu → đạt ngưỡng (`FACE_THRESHOLD` trong `env.dart`, khởi điểm 0.75; in giá trị ra log khi debug để nhóm hiệu chỉnh) →
  `POST /api/auth/face-login { deviceId, refreshToken }` → server kiểm `deviceId` thuộc `trustedDevices` và `faceLoginEnabled` → cấp token mới.
  Không cần OTP vì thiết bị đã được tin cậy sau một lần đăng nhập đủ mật khẩu + OTP.
- Sai 3 lần liên tiếp → bắt buộc đăng nhập mật khẩu + OTP.
- **Model:** `assets/models/mobilefacenet.tflite`. Đọc shape input/output từ interpreter lúc chạy, không hardcode 112 / 192. Không tự tải được file model → để trống, ghi hướng dẫn tải trong README; app vẫn build được và hiện "Thiếu model nhận diện" thay vì crash.

---

## 5. Tính năng mới: Giờ học an toàn (yêu cầu 6)

**Vấn đề:** các app quản lý trẻ phổ biến thường chỉ báo khi trẻ vào/ra một vùng, không phân biệt **rời trường lúc tan học** (bình thường) với **rời trường giữa giờ học** (bất thường). Phụ huynh hoặc bị báo liên tục, hoặc tắt luôn thông báo. *(Nhóm tự kiểm chứng lại với Google Family Link, Life360… trước khi thuyết trình.)*

**Giải pháp:** phụ huynh nhập thời khoá biểu của con (buổi học theo thứ, giờ vào – giờ ra, gắn với vùng loại "Trường"). Server tự đánh giá:

| Tình huống | Điều kiện | Cảnh báo |
|---|---|---|
| Chưa đến trường | quá giờ vào học + `graceMinutes` (mặc định 15) mà vị trí gần nhất chưa nằm trong vùng trường | `not_arrived_school` — mức vàng |
| Rời trường trong giờ học | trong khung giờ học, ở ngoài vùng liên tục ≥ `outsideToleranceMinutes` (mặc định 5) | `left_school_during_class` — mức đỏ, push ưu tiên cao, kèm vị trí hiện tại |
| Mất tín hiệu trong giờ học | `lastSeenAt` cũ hơn 15 phút trong khung giờ học | `device_offline_school_hours` — mức vàng |
| Quay lại trường | đã có cảnh báo đỏ, rồi vào lại vùng | `returned_to_school` — thông tin |
| Tan học bình thường | ra khỏi vùng trong 30 phút sau giờ tan | chỉ ghi nhật ký, không push |

- **"Ngoài vùng"** = khoảng cách haversine > `radius + max(accuracy, 30 m)` — chống GPS nhảy.
- **Chống spam:** mỗi loại cảnh báo tối đa 1 lần / buổi học / con (`dedupeKey = childId + sessionId + ngày + type`).
- **Ngày nghỉ:** phụ huynh bấm "Hôm nay con nghỉ học" (hoặc chọn ngày) → bỏ qua đánh giá ngày đó (`Child.schoolOffDates`).
- **Engine chạy ở 2 chỗ:** (1) mỗi khi nhận vị trí mới; (2) job node-cron mỗi phút cho các trường hợp không có vị trí mới (chưa đến trường, mất tín hiệu). Job đọc trạng thái từ DB, không giữ trong RAM (máy server có thể restart bất cứ lúc nào).
- **Liên hệ yêu cầu 7:** job chạy trên server → server ngủ là không ai canh → đây là lý do server phải luôn sống.
- **Code:** `webapi_dohonganhduy/src/modules/school-guard/`
  - `school-guard.engine.js` — hàm thuần (nhận buổi học, vùng, vị trí, thời điểm → trả danh sách cảnh báo), có unit test với dữ liệu giả cho từng tình huống trong bảng.
  - `school-guard.job.js` — job mỗi phút.
- **Demo trên lớp:** `npm run simulate -- --child <childId> --scenario <leave-during-class | arrive-late | normal-day> --create-demo-session`
  Script tự tạo buổi học tạm phủ giờ hiện tại, rồi gửi chuỗi vị trí giả qua đúng API của máy con → phụ huynh nhận cảnh báo đỏ ngay khi đang thuyết trình. Xoá buổi học tạm khi kết thúc.

---

## 6. CRUD (yêu cầu 4 — 5.5đ)

| # | Đối tượng | Ai dùng | Create | Read | Update | Delete |
|---|---|---|---|---|---|---|
| 1 | Người dùng | admin | tạo admin/staff/parent | danh sách: tìm theo tên/email/username, lọc role/status, phân trang; chi tiết | sửa thông tin, đổi role, khoá/mở | xoá mềm (`status = deleted`), không được xoá chính mình |
| 2 | Hồ sơ con | parent | tên, năm sinh, tên trường, màu avatar | danh sách card + chi tiết (vị trí cuối, pin, thiết bị) | sửa | xoá kèm toàn bộ dữ liệu liên quan + huỷ ghép thiết bị (có cảnh báo rõ trong dialog) |
| 3 | Vùng an toàn | parent | chạm bản đồ đặt tâm, slider bán kính 50–1000 m, loại `home / school / other`, bật/tắt báo vào/ra | danh sách theo con + xem trên bản đồ | sửa | xoá (không cho xoá vùng trường đang gắn thời khoá biểu — báo lý do) |
| 4 | Buổi học (thời khoá biểu) | parent | chọn nhiều thứ, giờ vào/ra, nhãn ("Sáng", "Chiều"), gắn vùng `school` | dạng lưới tuần | sửa | xoá; kiểm tra trùng giờ khi tạo/sửa |
| 5 | Lịch khoá máy | parent | tên, ngày trong tuần, giờ bắt đầu–kết thúc (cho phép qua nửa đêm, vd 21:30–06:30), app được phép, bật/tắt | danh sách theo con, nhãn "Đang hiệu lực" | sửa, bật/tắt nhanh bằng switch | xoá |
| 6 | Ticket hỗ trợ | parent tạo · staff xử lý · admin xem hết | tiêu đề, loại (`account / device / bug / other`), nội dung | parent: ticket của mình; staff: của mình + hàng chờ; lọc theo trạng thái | staff: nhận, đổi trạng thái `open → in_progress → resolved → closed`, trả lời; parent: thêm tin nhắn | parent xoá khi còn `open`; admin xoá bất kỳ |
| 7 | Cảnh báo | parent | (hệ thống tạo) | lọc theo con / loại / chưa đọc; badge số chưa đọc | đánh dấu đã đọc, đọc tất cả | xoá, xoá tất cả đã đọc |
| 8 | Thiết bị | parent | (tạo qua QR — Phase 5) | danh sách, trạng thái online, pin | đổi tên | huỷ ghép |

- Lịch khoá: gọi điện, tin nhắn, báo thức **luôn được phép** (không cho bỏ chọn). Danh sách app để chọn lấy từ máy con gửi lên (Phase 8); trước đó cho nhập tên gói thủ công.
- **Quy chuẩn UI cho mọi CRUD:** validate ngay tại ô nhập (cùng rule với backend); nút Lưu bị khoá khi đang gửi; xoá luôn có dialog xác nhận; thành công/thất bại báo SnackBar tiếng Việt; danh sách có tìm kiếm + pull-to-refresh + 4 trạng thái (loading / rỗng / lỗi / có dữ liệu).

---

## 7. Máy con: chế độ trẻ em & thực thi lịch khoá (phần native)

### 7.1 Màn hình con
- Banner minh bạch: "Bố mẹ thấy được: vị trí, pin, lịch khoá máy".
- Trạng thái hiện tại: "Đang trong giờ học" / "Đang trong giờ khoá máy đến 06:30" / "Tự do".
- Lịch hôm nay (buổi học + giờ khoá).
- Nút **SOS** to, giữ 2 giây mới gửi (tránh bấm nhầm) → `POST /api/devices/me/sos` kèm vị trí → cảnh báo đỏ cho phụ huynh.
- Chữ to, nút to, màu thân thiện, ít chữ.

### 7.2 Thực thi lịch khoá (mức đồ án, không cần Device Owner)
- Kotlin foreground service đọc app đang mở bằng `UsageStatsManager` (quyền "Truy cập dữ liệu sử dụng"), chu kỳ ~1 giây.
- Trong khung giờ khoá, nếu app đang mở không thuộc danh sách cho phép → mở `LockActivity` toàn màn hình: "Đang trong giờ nghỉ — đến HH:mm", kèm nút mở nhanh các app được phép.
- Luôn cho phép: chính app ConAn, launcher, app gọi điện mặc định (`TelecomManager`), app tin nhắn mặc định, app đồng hồ/báo thức (resolve intent `AlarmClock`), cuộc gọi khẩn cấp.
- Cấu hình lịch được cache trên máy (chạy được khi mất mạng); làm mới khi mở app, mỗi 15 phút, và khi nhận FCM data `config_changed`.
- Danh sách app trên máy con: chỉ app có icon ngoài launcher, khai báo `<queries>` với intent `MAIN/LAUNCHER` (không dùng `QUERY_ALL_PACKAGES`) → `POST /api/devices/me/apps`.
- Phát hiện quyền bị tắt → gửi cảnh báo `permission_revoked` cho phụ huynh.
- Ghi rõ giới hạn trong docs: trẻ vẫn có thể gỡ app / tắt quyền trong Cài đặt; chặn tuyệt đối cần Device Owner (ngoài phạm vi).
- MethodChannel `conan/native`: `hasUsageAccess`, `openUsageAccessSettings`, `canDrawOverlays`, `openOverlaySettings`, `openAppDetailsSettings`, `getLaunchableApps`, `startLockService(configJson)`, `updateLockConfig(configJson)`, `stopLockService`.

### 7.3 Màn hình "Kiểm tra quyền" (máy con)
Mỗi mục một dòng: trạng thái ✓/✗ + nút mở đúng trang cài đặt.
- Vị trí "Luôn cho phép", thông báo, truy cập dữ liệu sử dụng, hiển thị trên ứng dụng khác (cần để mở màn khoá từ nền trên Android 10+).
- **Riêng Xiaomi (MIUI/HyperOS):** Tự khởi chạy (Autostart), "Hiển thị cửa sổ bật lên khi đang chạy trong nền", Tiết kiệm pin → "Không giới hạn". Nhận diện Xiaomi qua `device_info_plus` (manufacturer), mở trang cài đặt bằng intent của MIUI, thất bại thì mở trang chi tiết ứng dụng + hướng dẫn bằng chữ.

---

## 8. Backend chi tiết

### 8.1 Collections (Mongoose)
- **User**: `username` (unique, lowercase) · `email` (unique) · `passwordHash` · `fullName` · `phone` · `role` (`admin|staff|parent`) · `status` (`pending|active|locked|deleted`) · `faceLoginEnabled` · `trustedDevices [{ deviceId, name, lastUsedAt }]` · `fcmTokens [String]` · timestamps
- **Otp**: `userId` · `purpose` (`verify_email|login|reset_password`) · `codeHash` · `attempts` · `expiresAt` (TTL) · `consumedAt`
- **RefreshToken**: `ownerType` (`user|device`) · `ownerId` · `tokenHash` · `expiresAt` (TTL) · `revokedAt` · `replacedBy`
- **Child**: `parentId` · `name` · `birthYear` · `schoolName` · `avatarColor` · `deviceId` · `lastLocation { lat, lng, accuracy, battery, at }` · `schoolOffDates [String YYYY-MM-DD]`
- **Device**: `childId` · `parentId` · `name` · `model` · `androidVersion` · `appVersion` · `pairedAt` · `lastSeenAt` · `batteryLevel` · `installedApps [{ packageName, label }]` · `fcmToken` · `status` (`active|unpaired`)
- **PairingCode**: `parentId` · `childId` · `codeHash` · `expiresAt` (TTL 10 phút) · `usedAt`
- **Location**: `childId` · `lat` · `lng` · `accuracy` · `speed` · `battery` · `recordedAt` — index `(childId, recordedAt)`, TTL 7 ngày
- **Geofence**: `parentId` · `childId` · `name` · `type` (`home|school|other`) · `center { lat, lng }` · `radiusM` · `notifyEnter` · `notifyExit` · `active`
- **SchoolSession**: `parentId` · `childId` · `geofenceId` · `daysOfWeek [1..7]` · `startTime "HH:mm"` · `endTime "HH:mm"` · `label` · `graceMinutes` · `outsideToleranceMinutes` · `active`
- **LockSchedule**: `parentId` · `childId` · `name` · `daysOfWeek [1..7]` · `startTime` · `endTime` · `allowedPackages [String]` · `enabled`
- **Alert**: `parentId` · `childId` · `type` · `level` (`info|warning|danger`) · `title` · `message` · `location` · `dedupeKey` (unique, sparse) · `readAt` · `createdAt`
  Loại: `left_school_during_class`, `not_arrived_school`, `device_offline_school_hours`, `returned_to_school`, `geofence_enter`, `geofence_exit`, `sos`, `low_battery`, `permission_revoked`
- **SupportTicket**: `parentId` · `assignedStaffId` · `subject` · `category` · `status` · `messages [{ senderId, senderRole, content, createdAt }]` · timestamps

### 8.2 API (tiền tố `/api`)
| Nhóm | Endpoint |
|---|---|
| Health | `GET /health` (ngoài `/api`, không cần đăng nhập) |
| Auth | `POST auth/register` · `auth/verify-email` · `auth/resend-otp` · `auth/login` · `auth/login/verify-otp` · `auth/face-login` · `auth/refresh` · `auth/logout` · `auth/forgot-password` · `auth/reset-password` · `GET auth/me` |
| Tài khoản | `PATCH users/me` · `PATCH users/me/password` · `PATCH users/me/face-login` · `PATCH users/me/fcm-token` |
| Admin | `GET/POST admin/users` · `GET/PATCH/DELETE admin/users/:id` · `PATCH admin/users/:id/status` · `GET admin/stats` |
| Con | `GET/POST children` · `GET/PATCH/DELETE children/:id` · `POST children/:id/pairing-code` · `POST/DELETE children/:id/off-dates` |
| Vị trí | `GET children/:id/locations/latest` · `GET children/:id/locations?date=YYYY-MM-DD` |
| Vùng an toàn | `GET/POST geofences?childId=` · `PATCH/DELETE geofences/:id` |
| Buổi học | `GET/POST school-sessions?childId=` · `PATCH/DELETE school-sessions/:id` |
| Lịch khoá | `GET/POST lock-schedules?childId=` · `PATCH/DELETE lock-schedules/:id` |
| Cảnh báo | `GET alerts?childId=&type=&unread=` · `PATCH alerts/:id/read` · `PATCH alerts/read-all` · `DELETE alerts/:id` · `DELETE alerts/read` |
| Thiết bị (phụ huynh) | `GET devices` · `PATCH devices/:id` · `DELETE devices/:id` · `POST devices/:id/locate-now` |
| Máy con | `POST devices/pair` · `POST devices/me/locations` · `GET devices/me/config` · `POST devices/me/apps` · `POST devices/me/sos` · `PATCH devices/me/fcm-token` · `POST devices/me/permission-status` |
| Ticket | `GET/POST tickets` · `GET/PATCH/DELETE tickets/:id` · `POST tickets/:id/messages` · `POST tickets/:id/claim` |

- Danh sách hỗ trợ `?page=&limit=&search=`, trả `{ items, page, limit, total }`.
- Swagger UI tại `/docs`, đọc từ `src/docs/openapi.yaml` — cập nhật mỗi khi thêm endpoint.

### 8.3 Socket.IO
- Chỉ máy phụ huynh kết nối (máy con dùng REST cho ổn định khi chạy nền).
- Kết nối xong tự join room `parent:<userId>`.
- Server → client: `location:new`, `alert:new`, `device:paired`, `device:status`. Tên event khai báo một chỗ ở `sockets/events.js`.

### 8.4 Push (FCM)
- Cảnh báo → notification tới mọi `fcmTokens` của phụ huynh (mức `danger` dùng kênh ưu tiên cao).
- Máy con nhận data message: `locate_now`, `config_changed`.
- Thiếu `FIREBASE_SERVICE_ACCOUNT_BASE64` → log cảnh báo và bỏ qua push; app vẫn chạy nhờ socket + danh sách cảnh báo.

### 8.5 Biến môi trường (`webapi_dohonganhduy/.env.example`)
`NODE_ENV` · `PORT` · `MONGODB_URI` · `MONGODB_DB_NAME=ConAnDB_DoHongAnhDuy` · `JWT_ACCESS_SECRET` · `JWT_REFRESH_SECRET` · `ACCESS_TOKEN_TTL=15m` · `REFRESH_TOKEN_TTL_DAYS=30` · `OTP_PEPPER` · `EMAIL_PROVIDER=gmail|brevo|console` · `GMAIL_USER` · `GMAIL_APP_PASSWORD` · `BREVO_API_KEY` · `MAIL_FROM_EMAIL` · `MAIL_FROM_NAME=ConAn` · `FIREBASE_SERVICE_ACCOUNT_BASE64` · `APP_TIMEZONE=Asia/Ho_Chi_Minh` · `SEED_ADMIN_USERNAME` · `SEED_ADMIN_EMAIL` · `SEED_ADMIN_PASSWORD` · `SEED_STAFF_*` · `SEED_PARENT_*`

`config/env.js` kiểm tra đủ biến bắt buộc bằng zod khi khởi động, thiếu thì báo rõ tên biến và thoát.

### 8.6 Seed & dữ liệu demo
- `npm run seed`: tạo admin / staff / parent từ biến `SEED_*` (email phải là email thật của nhóm để nhận OTP). Chạy lại không tạo trùng.
- `npm run seed:demo`: thêm dữ liệu cho buổi thuyết trình — 2 con, vùng "Nhà" + "Trường", thời khoá biểu T2–T6, 2 lịch khoá, vài cảnh báo, vài ticket ở các trạng thái khác nhau.

---

## 9. Deploy & "server luôn sống" (yêu cầu 7)

Server production chạy trên **máy Windows của nhóm**, mở ra Internet bằng **Tailscale Funnel** (miễn phí, URL HTTPS cố định, không cần mở port router, không cần mua tên miền, hỗ trợ WebSocket).

```
Điện thoại (4G/Wi-Fi bất kỳ)
   │ HTTPS + WebSocket
   ▼
https://webapi-dohonganhduy.<tailnet>.ts.net   ← Tailscale Funnel relay
   │ đường hầm mã hoá
   ▼
Máy Windows: Tailscale ──► WebAPI_DoHongAnhDuy :3000 (npm start) ──► MongoDB Atlas: ConAnDB_DoHongAnhDuy
```

### 9.1 Thành phần
- **Node.js production** chạy phía Windows (không phải WSL), cổng 3000, bằng `npm start` trong `webapi_dohonganhduy/`. Nhóm quyết định không dùng NSSM: server chỉ cần chạy khi có người cần kết nối, cửa sổ PowerShell phải để mở. `install-service.ps1` và `update.ps1` (dùng NSSM) giữ lại làm tuỳ chọn.
- **Tailscale** (cài bản Windows, chạy sẵn như service): đổi tên máy trong trang quản trị Tailscale thành `webapi-dohonganhduy` (để URL có tên cá nhân), rồi `tailscale funnel --bg 3000` → cấu hình được giữ qua các lần khởi động lại máy.
- **MongoDB Atlas M0** (cluster `Cluster-DoHongAnhDuy`, database `ConAnDB_DoHongAnhDuy`) giữ nguyên ở cloud: máy server có hỏng thì dữ liệu vẫn còn. Network Access chỉ cần cho phép IP nhà/IP hiện tại của máy server (nếu IP nhà đổi thường xuyên thì dùng `0.0.0.0/0` + mật khẩu DB dài, ngẫu nhiên).
- **Email:** chạy trên máy nhà không bị chặn SMTP → dùng Gmail SMTP App Password (mục 3.3).
- **Theo dõi:** UptimeRobot (free) gọi `GET <url>/health` mỗi 5 phút, máy server tắt thì báo email cho nhóm. Không còn cần ping giữ thức.

### 9.2 Thư mục `deploy/` (PowerShell, chạy bằng quyền Administrator, có comment tiếng Việt từng bước)
- `install-service.ps1` — kiểm tra Node/NSSM đã cài chưa (thiếu thì in hướng dẫn tải, không tự tải file lạ), `npm ci --omit=dev` trong `webapi_dohonganhduy`, tạo service `WebAPI_DoHongAnhDuy` với `NODE_ENV=production`, thư mục làm việc, file log, chế độ tự khởi động.
- `start-funnel.ps1` — kiểm tra Tailscale đã đăng nhập, chạy `tailscale funnel --bg 3000`, in ra URL public.
- `update.ps1` — `git pull` → `npm ci --omit=dev` → restart service → gọi `/health` xác nhận.
- `check.ps1` — in trạng thái service, funnel, `/health` local và public, 20 dòng log cuối.
- File `.env` production đặt ở `webapi_dohonganhduy/.env` trên máy server, không commit.

### 9.3 Cấu hình máy để chạy 24/7 (README hướng dẫn, script `check.ps1` nhắc nếu sai)
- Power: khi cắm sạc **không bao giờ Sleep/Hibernate**; nếu là laptop: gập màn hình → "Do nothing".
- Windows Update: đặt Active hours, tạm hoãn update quanh ngày demo; service tự chạy lại sau khi máy khởi động lại.
- Wi-Fi/mạng: ưu tiên cắm dây LAN; tắt chế độ tiết kiệm điện của card mạng.
- Laptop cắm sạc liên tục: bật giới hạn sạc pin (~80%) nếu máy có hỗ trợ.

### 9.4 `/health` và khả năng chịu lỗi
- `/health` trả `{ status: "ok", uptime, db: "connected" | "down", time }`, nhẹ, không cần đăng nhập.
- Máy server có thể restart / mất mạng → dio retry có backoff cho 502/503/timeout, socket tự reconnect, máy con xếp hàng vị trí khi gửi lỗi, job đọc lại trạng thái từ DB khi khởi động.

### 9.5 Dự phòng
- Funnel có giới hạn băng thông (Tailscale không công bố con số) — app chỉ gửi JSON nhỏ nên không đáng lo, nhưng **không** gửi ảnh/video qua server.
- Nếu Funnel lỗi hôm demo: chạy `cloudflared tunnel --url http://localhost:3000` (Quick Tunnel, URL ngẫu nhiên) và build lại app với `--dart-define=API_BASE_URL=<url mới>`. Chỉ dùng khẩn cấp.
- Nếu máy server phải mang đi (lên lớp…), server sẽ tắt → cả nhóm không dùng được app trong lúc đó. Ngày demo nên để máy server ở nhà chạy ổn định, hoặc mang theo và chạy trên mạng của lớp/4G (Funnel vẫn hoạt động, URL không đổi).

### 9.6 README phải có
Hướng dẫn từng bước: tạo Atlas; tạo Gmail App Password; Firebase (`google-services.json`); cài Node + NSSM + Tailscale trên máy server; chạy `deploy/*.ps1`; cấu hình nguồn điện; tạo UptimeRobot; và cách build APK gửi nhóm: `flutter build apk --release --dart-define=API_BASE_URL=https://webapi-dohonganhduy.<tailnet>.ts.net`.

---

## 10. Giao diện (yêu cầu 7)

- Material 3, `ColorScheme.fromSeed` tông xanh ngọc (an toàn, tin cậy); cảnh báo đỏ / vàng rõ ràng, nhất quán. Dark mode theo hệ thống.
- Font **Be Vietnam Pro** đóng gói trong `assets/fonts` (hỗ trợ tiếng Việt đầy đủ, không tải lúc chạy). Không tải được thì dùng font mặc định và ghi chú.
- **Phụ huynh** — bottom nav 4 tab: *Tổng quan* (card mỗi con: online, pin, đang ở đâu "Ở trường / Ở nhà / Ngoài vùng", cảnh báo mới nhất) · *Bản đồ* · *Lịch* (khoá máy + thời khoá biểu) · *Cài đặt* (tài khoản, khuôn mặt, thiết bị, hỗ trợ). Chuông cảnh báo có badge ở AppBar.
- **Admin** — *Thống kê* (thẻ số liệu: người dùng theo role, thiết bị online 15 phút qua, cảnh báo hôm nay, ticket đang mở) · *Người dùng* · *Ticket*.
- **Nhân viên** — *Hàng chờ* · *Của tôi* · *Đã xong*, kèm số liệu nhanh ở đầu dashboard.
- **Máy con** — theo mục 7.1.
- Màn đăng nhập/đăng ký gọn, có logo, nút to, hiện/ẩn mật khẩu, ô OTP 6 ô tự nhảy, đếm ngược "Gửi lại mã".
- Thông báo lỗi chung gom ở `lib/core/network/api_exception.dart` (map mã lỗi server → câu tiếng Việt dễ hiểu).

---

## 11. Các phase

Mỗi phase xong phải chạy được và được nhóm kiểm tra trước khi sang phase sau.

- [ ] **Phase 0 — Khung dự án:** tạo đúng cây thư mục, project Flutter `btkt_dohonganhduy` **đã có sẵn** — không `flutter create` lại; đổi applicationId/namespace sang `com.dohonganhduy.btkt_dohonganhduy` (chuyển `MainActivity.kt` theo), label app `ConAn`, `minSdk = 24`, thay `lib/main.dart` mẫu và `test/widget_test.dart` mẫu bằng khung theo CLAUDE.md, thêm `analysis_options` exclude `webapi_dohonganhduy/**`, bổ sung `.gitignore`; tạo `webapi_dohonganhduy/` + `npm init`, `npm init` + script `dev / start / test / lint / seed / seed:demo / simulate`, `.gitignore` (gồm `.env`), `.env.example`, README khung, `docs/PROGRESS.md`. *Kiểm tra:* app mặc định chạy được; `npm run dev` → `/health` trả ok kèm `project`, `student`, `database` đúng tên cá nhân; `flutter analyze` sạch.
- [ ] **Phase 1 — Backend nền + Auth:** config, db, models User/Otp/RefreshToken, module auth đủ luồng mục 3, `authenticate` + `requireRole`, errorHandler, rate limit, email service (gmail + brevo + console), seed. Test jest + supertest + mongodb-memory-server: đăng ký, xác minh OTP, đăng nhập 2 bước, refresh xoay vòng, chặn sai role.
- [ ] **Phase 2 — Deploy lên máy này:** viết `deploy/*.ps1` + README mục 9 (Atlas, Gmail App Password, NSSM, Tailscale Funnel, cấu hình nguồn, UptimeRobot). Nhóm chạy script bằng PowerShell Administrator; Claude kiểm tra bằng `check.ps1`, gọi `/health` qua URL Funnel từ 4G điện thoại và thử đăng ký thật. Từ phase này app mặc định trỏ production.
- [ ] **Phase 3 — Mobile nền + Auth UI:** theme, router + redirect theo role, dio + interceptor refresh + retry, secure storage, màn chọn loại máy, đăng ký, xác minh email, đăng nhập, OTP, quên mật khẩu, 3 home shell (admin / staff / parent) có bottom nav trống.
- [ ] **Phase 4 — CRUD:** backend + UI cho mục 6 theo thứ tự: người dùng → hồ sơ con → vùng an toàn → buổi học → lịch khoá → ticket → cảnh báo (thiết bị làm ở Phase 5). Xong mỗi nhóm: test API + chạy thử trên app.
- [ ] **Phase 5 — QR + chế độ con + vị trí realtime:** mục 4.1, 4.2, CRUD thiết bị, socket, màn Bản đồ, dịch vụ nền máy con, màn kiểm tra quyền (phần vị trí + thông báo + Xiaomi).
- [ ] **Phase 6 — Đăng nhập khuôn mặt:** mục 4.3.
- [ ] **Phase 7 — Giờ học an toàn + push:** mục 5, FCM (mục 8.4), nút "Định vị ngay", script `simulate`, unit test engine.
- [ ] **Phase 8 — Lịch khoá trên máy con + SOS:** mục 7.1, 7.2, phần còn lại của 7.3.
- [ ] **Phase 9 — Hoàn thiện:** rà toàn bộ UI theo mục 10, `seed:demo`, `docs/demo-script.md` (kịch bản thuyết trình ~10 phút: thứ tự demo, ai nói phần nào, thao tác gì, phương án nếu mạng lỗi), build APK release, README mục "Chạy trong 5 phút" cho thành viên mới.
