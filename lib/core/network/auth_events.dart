// Kênh sự kiện xác thực toàn app: lớp mạng báo "phiên hết hạn" / "máy con bị huỷ ghép",
// SessionController lắng nghe để đưa người dùng về đúng màn hình (tránh phụ thuộc vòng giữa các provider).
import 'dart:async';

enum AuthEvent { sessionExpired, deviceUnpaired }

class AuthEvents {
  AuthEvents._();

  static final _controller = StreamController<AuthEvent>.broadcast();

  static Stream<AuthEvent> get stream => _controller.stream;

  static void emit(AuthEvent event) => _controller.add(event);
}
