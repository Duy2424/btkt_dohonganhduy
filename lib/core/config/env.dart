// Cấu hình lúc build: URL Web API (mặc định là URL Tailscale Funnel dùng chung cho cả nhóm)
// và ngưỡng nhận diện khuôn mặt. Đổi khi build: --dart-define=API_BASE_URL=https://...
class Env {
  Env._();

  /// URL Web API production (Tailscale Funnel trên máy server của nhóm).
  /// Cả nhóm clone về bấm Run là nối thẳng server này.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://webapi-dohonganhduy.tail7e7968.ts.net',
  );

  /// Ngưỡng cosine similarity để chấp nhận khuôn mặt (0..1). Nhóm hiệu chỉnh theo log debug.
  static const _faceThresholdRaw = String.fromEnvironment('FACE_THRESHOLD', defaultValue: '0.75');
  static double get faceThreshold => double.tryParse(_faceThresholdRaw) ?? 0.75;

  static const appVersion = '1.0.0';
  static const projectName = 'btkt_dohonganhduy';
  static const studentName = 'Đỗ Hồng Anh Duy';
}
