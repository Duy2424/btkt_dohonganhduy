# Kịch bản thuyết trình ConAn (khoảng 10 phút)

Project `btkt_dohonganhduy`, sinh viên Đỗ Hồng Anh Duy, Web API `webapi-dohonganhduy`, database `ConAnDB_DoHongAnhDuy`.

## Chuẩn bị (30 phút trước giờ thuyết trình)

- Trên máy server mở PowerShell, `cd webapi_dohonganhduy` rồi `npm start`. Chạy `deploy\check.ps1` để chắc `/health` trả lời được cả local lẫn public.
- Chạy `npm run seed` (nếu chưa) và `npm run seed:demo`. Tài khoản phụ huynh sẽ có 2 con là An và Bin. Bin không có máy thật, dùng để giả lập vị trí.
- Điện thoại Xiaomi (máy con) đã ghép với An và cấp đủ quyền. Emulator hoặc một điện thoại khác đăng nhập tài khoản phụ huynh.
- Lấy `childId` của Bin: `seed:demo` in ra sẵn, hoặc gọi `GET /api/children` trong Swagger `/docs`.
- Mở sẵn tab trình duyệt `https://webapi-dohonganhduy.tail7e7968.ts.net/health`.

| # | Thời lượng | Người nói | Nội dung | Thao tác |
|---|---|---|---|---|
| 1 | 0:45 | Thành viên 1 | Bài toán và tên cá nhân | Mở `/health`, chỉ vào `project`, `student`, `database`. Trong app vào Cài đặt, Giới thiệu |
| 2 | 1:30 | Thành viên 1 | Yêu cầu 1–2: đăng ký email, đăng nhập bằng username, mật khẩu và OTP | Đăng ký tài khoản mới, mở mail lấy OTP (6 ô, có đếm ngược gửi lại), xác minh, đăng nhập, nhập OTP lần hai |
| 3 | 1:00 | Thành viên 2 | Yêu cầu 3: phân quyền | `admin` vào Trang quản trị, `staff` vào Dashboard nhân viên, phụ huynh vào Tổng quan. Admin và nhân viên không xem được vị trí của trẻ, server trả 403 |
| 4 | 2:00 | Thành viên 2 | Yêu cầu 4: CRUD | Admin tìm, khoá, mở người dùng. Phụ huynh thêm con, tạo vùng an toàn (chạm bản đồ, kéo bán kính), thêm buổi học (thử trùng giờ để thấy báo lỗi), tạo lịch khoá 21:30–06:30 rồi bật tắt, gửi ticket để nhân viên nhận và trả lời. Mọi thao tác xoá đều hỏi xác nhận |
| 5 | 1:00 | Thành viên 3 | Nâng cao: QR ghép máy | Hồ sơ An, Ghép điện thoại, QR hiện kèm đếm ngược 10 phút. Máy con quét xong thì máy phụ huynh tự chuyển sang "Ghép thành công" nhờ socket |
| 6 | 1:00 | Thành viên 3 | Nâng cao: chia sẻ vị trí | Tab Bản đồ: marker của An cập nhật realtime, kèm pin và "cập nhật X phút trước". Xem lịch sử theo ngày. Máy con luôn có thông báo cố định cho biết đang chia sẻ vị trí |
| 7 | 1:00 | Thành viên 4 | Nâng cao: đăng nhập khuôn mặt | Cài đặt, Đăng nhập bằng khuôn mặt, chụp 5 ảnh và nhập lại mật khẩu. Đăng xuất, chọn đăng nhập bằng khuôn mặt, chớp mắt là vào. Dữ liệu khuôn mặt chỉ nằm trên máy, không gửi lên server |
| 8 | 1:15 | Thành viên 4 | Yêu cầu 6: Giờ học an toàn | Nói vấn đề trước: báo mỗi lần vào ra vùng thì phụ huynh bị spam. Chạy `npm run simulate -- --child <id Bin> --scenario leave-during-class --create-demo-session`, máy phụ huynh nhận cảnh báo đỏ "Con rời trường trong giờ học" rồi "Con đã quay lại trường". Chạy thêm `--scenario normal-day` để thấy tan học bình thường thì không có push |
| 9 | 0:30 | Thành viên 5 | SOS và khoá máy | Máy con giữ nút SOS 2 giây, phụ huynh nhận cảnh báo đỏ. Nếu đang trong giờ khoá, mở một app bị chặn để thấy màn "Đang trong giờ nghỉ" |
| 10 | 0:30 | Thành viên 5 | Yêu cầu 7: giao diện và cả nhóm chạy được | Bật dark mode, font Be Vietnam Pro. Server chạy trên máy nhóm và mở ra Internet bằng Tailscale Funnel, UptimeRobot theo dõi. Ai clone repo bấm Run cũng nối vào server này, máy chỉ cài APK cũng vậy |

## Nếu có sự cố

- Mạng ở lớp chặn hoặc Funnel lỗi: phát 4G từ điện thoại cho cả hai máy. Nếu vẫn lỗi, trên máy server chạy `cloudflared tunnel --url http://localhost:3000` rồi build lại app với `--dart-define=API_BASE_URL=<url mới>`.
- Không nhận được mail OTP: xem thư mục Spam. Dự phòng thì đổi `EMAIL_PROVIDER=brevo` trong `.env`, bấm Ctrl+C ở cửa sổ server rồi chạy lại `npm start`.
- Máy Xiaomi không gửi vị trí: mở màn Kiểm tra quyền (Autostart, Tiết kiệm pin để Không giới hạn). Vẫn có thể demo bản đồ và cảnh báo bằng `npm run simulate` với Bin.
- Khuôn mặt không khớp vì thiếu sáng: bấm "Dùng mật khẩu + OTP" và giải thích ngưỡng `FACE_THRESHOLD`.
- Push không đến vì chưa cấu hình Firebase: cảnh báo vẫn hiện realtime qua socket, có thông báo cục bộ và nằm trong danh sách Cảnh báo.
