// Lưu dữ liệu nhạy cảm bằng flutter_secure_storage (Android Keystore): token đăng nhập, token máy con,
// token & mẫu khuôn mặt. Có cache trong RAM để interceptor đọc nhanh.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  SecureStore._();
  static final instance = SecureStore._();

  static const _storage = FlutterSecureStorage();

  static const kAccess = 'access_token';
  static const kRefresh = 'refresh_token';
  static const kDeviceToken = 'device_token';
  static const kFaceToken = 'face_token';
  static const kFaceTemplate = 'face_template';
  static const kFaceUserId = 'face_user_id';
  static const kFaceUserName = 'face_user_name';

  final Map<String, String?> _cache = {};

  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    final value = await _storage.read(key: key);
    _cache[key] = value;
    return value;
  }

  Future<void> write(String key, String? value) async {
    _cache[key] = value;
    if (value == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  String? cached(String key) => _cache[key];

  Future<void> saveSession(String access, String refresh) async {
    await write(kAccess, access);
    await write(kRefresh, refresh);
  }

  Future<void> clearSession() async {
    await write(kAccess, null);
    await write(kRefresh, null);
  }

  Future<void> clearFace() async {
    for (final k in [kFaceToken, kFaceTemplate, kFaceUserId, kFaceUserName]) {
      await write(k, null);
    }
  }
}
