# ConAn: app quản lý điện thoại trẻ em

Đồ án Lập trình di động, project `btkt_dohonganhduy`, sinh viên Đỗ Hồng Anh Duy.
Web API nằm ở `webapi_dohonganhduy/`, database `ConAnDB_DoHongAnhDuy`.
Đặc tả: [docs/SPEC.md](docs/SPEC.md). Tiến độ: [docs/PROGRESS.md](docs/PROGRESS.md). Kịch bản thuyết trình: [docs/demo-script.md](docs/demo-script.md).

## Chạy app (thành viên nhóm)

1. Clone repo, mở thư mục `btkt_dohonganhduy` bằng Android Studio.
2. Chạy `flutter pub get` rồi bấm Run. App tự nối vào server của nhóm ở `https://webapi-dohonganhduy.tail7e7968.ts.net` (ghi trong `lib/core/config/env.dart`), không ai phải chạy backend.
3. Nếu Windows báo "Building with plugins requires symlink support", bật Developer Mode bằng lệnh `start ms-settings:developers`.

Chỉ cần cài app thì tải `app-release.apk` ở mục Releases của repo trên GitHub, mở file trên điện thoại và cho phép cài từ nguồn này.

## Dựng server trên máy Windows của nhóm

Web API chạy ngay trên laptop của nhóm, dữ liệu nằm trên MongoDB Atlas, còn Tailscale Funnel cho nó một địa chỉ HTTPS cố định. Điện thoại nào có Internet cũng vào được, kể cả máy chỉ cài APK. Đổi lại, laptop phải bật và có mạng thì app mới chạy.

### 1. Gmail App Password (gửi OTP thật)

1. Vào https://myaccount.google.com/security và bật Xác minh 2 bước nếu chưa bật.
2. Mở https://myaccount.google.com/apppasswords, đặt tên (ví dụ `ConAn`) rồi bấm Tạo.
3. Google hiện một mật khẩu 16 ký tự, chỉ hiện một lần. Chép lại, bỏ dấu cách.

Mật khẩu này dán thẳng vào `.env`, đừng gửi qua chat hay commit lên Git.

### 2. MongoDB Atlas

1. Đăng ký ở https://cloud.mongodb.com, tạo cluster gói Free (M0) tên `Cluster-DoHongAnhDuy`.
2. Database Access: thêm một user DB. Mật khẩu nên chỉ gồm chữ và số, vì ký tự đặc biệt phải mã hoá URL mới dùng được trong chuỗi kết nối.
3. Network Access: IP nhà mạng hay đổi nên chọn Allow access from anywhere (`0.0.0.0/0`). Lớp bảo vệ lúc này là mật khẩu user DB.
4. Bấm Connect, chọn Drivers, chép chuỗi `mongodb+srv://...` và thay `<db_password>` bằng mật khẩu ở bước 2.

### 3. Điền `.env` và kiểm tra

Trên máy server, `webapi_dohonganhduy\.env` đã có sẵn các secret ngẫu nhiên. Máy khác thì chép từ `.env.example` và tạo secret theo hướng dẫn trong file. Cần điền:

- `MONGODB_URI`: chuỗi kết nối ở bước 2
- `GMAIL_USER` và `MAIL_FROM_EMAIL`: địa chỉ Gmail đã tạo App Password
- `GMAIL_APP_PASSWORD`: mật khẩu 16 ký tự
- `SEED_*`: tài khoản admin, nhân viên, phụ huynh mẫu. Email phải là email thật vì đăng nhập có bước OTP.

```
cd webapi_dohonganhduy
npm ci
npm run check:setup -- email.cua.ban@gmail.com
npm run seed
```

`check:setup` thử kết nối Atlas và gửi một mail OTP mẫu tới địa chỉ bạn đưa. `seed` tạo 3 tài khoản mẫu, chạy lại không bị trùng.

### 4. Chạy Web API

Mở một cửa sổ PowerShell tại thư mục repo:

```
cd webapi_dohonganhduy
npm start
```

Nếu PowerShell báo "running scripts is disabled on this system" thì gõ `npm.cmd` thay cho `npm` (ví dụ `npm.cmd start`), các lệnh npm khác cũng vậy.

Server chạy cổng 3000 và đọc `.env`. Thấy dòng `ConAn Web API (production) đang chạy tại http://localhost:3000` là được. Cửa sổ này phải để mở suốt lúc cần người khác kết nối. Tắt cửa sổ, tắt máy hay máy ngủ thì app sẽ báo không kết nối được, khi đó mở lại và chạy `npm start` lần nữa.

Muốn server tự chạy nền khi bật máy thì có sẵn `deploy\install-service.ps1` (cần cài NSSM). Nhóm hiện không dùng cách này.

### 5. Mở ra Internet bằng Tailscale Funnel

1. Cài Tailscale ở https://tailscale.com/download và đăng nhập.
2. Ở https://login.tailscale.com/admin/machines, đổi tên máy thành `webapi-dohonganhduy`.
3. Chạy (Administrator): `powershell -ExecutionPolicy Bypass -File deploy\start-funnel.ps1`. Lần đầu, nếu Tailscale in ra một đường link để bật HTTPS hay Funnel, mở link đó, bấm bật rồi chạy lại script.
4. Script in ra URL dạng `https://webapi-dohonganhduy.<tên-tailnet>.ts.net`. Mở `<URL>/health` trên điện thoại đang dùng 4G để chắc là ngoài mạng nhà vẫn vào được.

### 6. Gắn URL vào app và phát hành APK

1. Sửa `defaultValue` trong `lib/core/config/env.dart` thành URL ở bước 5 rồi commit, để ai clone về cũng nối đúng server.
2. Build: `flutter build apk --release`. File nằm ở `build\app\outputs\flutter-apk\app-release.apk` (khoảng 124 MB vì chứa thư viện cho mọi loại chip). Muốn file nhẹ hơn thì thêm `--split-per-abi` và chỉ đưa lên `app-arm64-v8a-release.apk`, file này chạy được trên hầu hết điện thoại Android đời mới.
3. Tạo một Release trên GitHub và đính kèm file APK. Ai tải về cài cũng dùng chung database với nhóm.

Bản release đang ký bằng debug key của máy build. APK build từ máy khác sẽ không cài đè được, phải gỡ bản cũ trước.

### Giữ server sống

- Khi cắm sạc, đặt máy không bao giờ Sleep hay Hibernate, gập máy thì Do nothing. `deploy\check.ps1` kiểm tra server, Funnel, `/health` và cấu hình nguồn.
- Tạo monitor trên UptimeRobot gọi `<URL>/health` mỗi 5 phút để biết khi server chết.
- Cập nhật code server: `git pull`, rồi trong cửa sổ đang chạy server bấm Ctrl+C và chạy lại `npm start`.

## Phát triển backend

```
cd webapi_dohonganhduy
npm install
npm test
npm run lint
npm run dev:memory
npm run dev
```

- `npm test`: 43 test (auth, JWT, CRUD, ghép QR, engine Giờ học an toàn), chạy trên MongoDB in-memory.
- `npm run dev:memory`: cổng 4000, database in-memory, có sẵn `admin01`, `staff01`, `parent01` (mật khẩu `Matkhau123`), OTP in ra terminal.
- `npm run dev`: đọc `.env.development`, cổng 4000, database `ConAnDB_DoHongAnhDuy_dev`.

App trỏ vào server dev trên emulator: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000`.
Swagger ở `<url>/docs`, còn `<url>/health` trả tên project, sinh viên và database.

## Demo "Giờ học an toàn"

```
npm run seed:demo
npm run simulate -- --child <childId> --scenario leave-during-class --create-demo-session
```

Có 3 kịch bản: `leave-during-class` (rời trường trong giờ học, cảnh báo đỏ), `arrive-late` (quá giờ chưa đến trường) và `normal-day` (tan học bình thường, không gửi push).

## Tuỳ chọn

- Push (FCM): tạo Firebase project với package `com.dohonganhduy.btkt_dohonganhduy`, đặt `android/app/google-services.json` (không commit) và thêm plugin `com.google.gms.google-services` vào Gradle. Phía server, mã hoá service account sang base64 rồi điền `FIREBASE_SERVICE_ACCOUNT_BASE64`. Thiếu phần này app vẫn nhận cảnh báo qua socket.
- Model khuôn mặt: đặt `mobilefacenet.tflite` (MobileFaceNet, đầu vào 112×112×3) vào `assets/models/`. Thiếu file thì màn khuôn mặt báo "Thiếu model nhận diện".
