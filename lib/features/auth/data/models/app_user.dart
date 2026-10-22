// Model người dùng đang đăng nhập + kết quả các bước xác thực (phiên OTP, cặp token).
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone = '',
    this.status = 'active',
    this.faceLoginEnabled = false,
    this.createdAt,
  });

  final String id;
  final String username;
  final String email;
  final String fullName;
  final String role; // admin | staff | parent
  final String phone;
  final String status;
  final bool faceLoginEnabled;
  final DateTime? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        username: (j['username'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        fullName: (j['fullName'] ?? '') as String,
        role: (j['role'] ?? 'parent') as String,
        phone: (j['phone'] ?? '') as String,
        status: (j['status'] ?? 'active') as String,
        faceLoginEnabled: (j['faceLoginEnabled'] ?? false) as bool,
        createdAt: j['createdAt'] == null ? null : DateTime.tryParse(j['createdAt'] as String),
      );

  /// Đường dẫn trang chủ theo vai trò (yêu cầu 3 của đề).
  String get homePath => switch (role) {
        'admin' => '/admin',
        'staff' => '/staff',
        _ => '/parent',
      };
}

/// Phiên OTP server trả về sau đăng ký / đăng nhập / quên mật khẩu.
class OtpChallenge {
  const OtpChallenge({required this.otpSessionId, required this.maskedEmail, this.resendAfter = 60});
  final String otpSessionId;
  final String maskedEmail;
  final int resendAfter;

  factory OtpChallenge.fromJson(Map<String, dynamic> j) => OtpChallenge(
        otpSessionId: j['otpSessionId'] as String,
        maskedEmail: (j['maskedEmail'] ?? '') as String,
        resendAfter: (j['resendAfter'] ?? 60) as int,
      );
}

/// Kết quả đăng nhập thành công.
class AuthResult {
  const AuthResult({required this.accessToken, required this.refreshToken, required this.user, this.faceToken});
  final String accessToken;
  final String refreshToken;
  final AppUser user;
  final String? faceToken;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        user: AppUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
        faceToken: j['faceToken'] as String?,
      );
}
