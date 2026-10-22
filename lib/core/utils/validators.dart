// Kiểm tra dữ liệu nhập ngay tại ô, cùng luật với backend (webapi_dohonganhduy/src/modules/auth/auth.schema.js).
// Mỗi hàm trả về null nếu hợp lệ, hoặc câu báo lỗi tiếng Việt.
class Validators {
  Validators._();

  static final _username = RegExp(r'^[a-z0-9_]{3,20}$');
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _phone = RegExp(r'^(\+?\d{9,12})?$');

  static String? required(String? v, [String label = 'thông tin này']) =>
      (v == null || v.trim().isEmpty) ? 'Vui lòng nhập $label' : null;

  static String? username(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    if (s.isEmpty) return 'Vui lòng nhập tên đăng nhập';
    if (!_username.hasMatch(s)) return 'Tên đăng nhập 3–20 ký tự, chỉ gồm chữ thường, số và dấu _';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Vui lòng nhập email';
    if (!_email.hasMatch(s)) return 'Email không hợp lệ';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (s.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    if (s.length > 72) return 'Mật khẩu tối đa 72 ký tự';
    if (!RegExp(r'[A-Za-z]').hasMatch(s)) return 'Mật khẩu phải có chữ cái';
    if (!RegExp(r'\d').hasMatch(s)) return 'Mật khẩu phải có chữ số';
    return null;
  }

  static String? fullName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Vui lòng nhập họ tên';
    if (s.length < 2) return 'Họ tên tối thiểu 2 ký tự';
    if (s.length > 60) return 'Họ tên tối đa 60 ký tự';
    return null;
  }

  static String? phone(String? v) =>
      _phone.hasMatch((v ?? '').trim()) ? null : 'Số điện thoại không hợp lệ';

  static String? otp(String? v) =>
      RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'Mã OTP gồm 6 chữ số';

  static String? maxLength(String? v, int max, String label) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Vui lòng nhập $label';
    if (s.length > max) return '${label[0].toUpperCase()}${label.substring(1)} tối đa $max ký tự';
    return null;
  }

  static String? birthYear(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final y = int.tryParse(v.trim());
    final now = DateTime.now().year;
    if (y == null || y < now - 20 || y > now) return 'Năm sinh không hợp lệ';
    return null;
  }

  static String? packageName(String? v) =>
      RegExp(r'^[a-zA-Z][\w]*(\.[\w]+)+$').hasMatch((v ?? '').trim()) ? null : 'Tên gói ứng dụng không hợp lệ (vd com.android.chrome)';
}
