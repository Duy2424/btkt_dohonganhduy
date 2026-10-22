// Test điều hướng theo role (yêu cầu 3) và bộ kiểm tra dữ liệu nhập (cùng luật với server).
import 'package:btkt_dohonganhduy/app/router.dart';
import 'package:btkt_dohonganhduy/core/storage/local_prefs.dart';
import 'package:btkt_dohonganhduy/core/utils/date_utils.dart';
import 'package:btkt_dohonganhduy/core/utils/validators.dart';
import 'package:btkt_dohonganhduy/features/auth/data/models/app_user.dart';
import 'package:btkt_dohonganhduy/features/auth/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser user(String role) => AppUser(id: '1', username: 'u', email: 'u@x.vn', fullName: 'U', role: role);

void main() {
  group('Điều hướng theo role', () {
    test('chưa đọc xong storage → splash; chưa chọn loại máy → onboarding', () {
      expect(redirectFor(const SessionState(), '/parent'), '/splash');
      expect(redirectFor(const SessionState(ready: true), '/login'), '/onboarding');
    });

    test('chưa đăng nhập → /login, nhưng vẫn vào được đăng ký / OTP', () {
      const s = SessionState(ready: true, mode: AppMode.parent);
      expect(redirectFor(s, '/parent'), '/login');
      expect(redirectFor(s, '/register'), isNull);
      expect(redirectFor(s, '/otp'), isNull);
    });

    test('mỗi role về đúng trang chủ, vào nhầm khu khác bị đẩy về', () {
      for (final (role, home) in [('admin', '/admin'), ('staff', '/staff'), ('parent', '/parent')]) {
        final s = SessionState(ready: true, mode: AppMode.parent, user: user(role));
        expect(redirectFor(s, '/login'), home);
        expect(redirectFor(s, home), isNull);
      }
      final staff = SessionState(ready: true, mode: AppMode.parent, user: user('staff'));
      expect(redirectFor(staff, '/admin'), '/staff');
      expect(redirectFor(staff, '/parent/children/1'), '/staff');
      expect(redirectFor(staff, '/account'), isNull);
    });

    test('máy con: chưa ghép → quét QR; đã ghép → /child', () {
      expect(redirectFor(const SessionState(ready: true, mode: AppMode.child), '/child'), '/child/pair');
      expect(redirectFor(const SessionState(ready: true, mode: AppMode.child, childPaired: true), '/parent'), '/child');
      expect(redirectFor(const SessionState(ready: true, mode: AppMode.child, childPaired: true), '/child/permissions'), isNull);
    });
  });

  group('Validators (cùng luật với backend)', () {
    test('username, mật khẩu, email', () {
      expect(Validators.username('Duy_01'), isNull); // tự chuyển chữ thường
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.password('abcdefgh'), 'Mật khẩu phải có chữ số');
      expect(Validators.password('Matkhau123'), isNull);
      expect(Validators.email('duy@gmail.com'), isNull);
      expect(Validators.email('duy@'), isNotNull);
    });
  });

  group('Lịch qua nửa đêm', () {
    test('21:30–06:30: 23h Thứ 2 và 05h Thứ 3 đều đang khoá', () {
      // 2026-10-19 là Thứ 2
      expect(AppDates.isWithinWindow([1], '21:30', '06:30', DateTime(2026, 10, 19, 23)), isTrue);
      expect(AppDates.isWithinWindow([1], '21:30', '06:30', DateTime(2026, 10, 20, 5)), isTrue);
      expect(AppDates.isWithinWindow([1], '21:30', '06:30', DateTime(2026, 10, 20, 7)), isFalse);
    });
  });
}
