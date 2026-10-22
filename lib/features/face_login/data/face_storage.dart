// Lưu mẫu khuôn mặt (embedding đã chuẩn hoá) trong flutter_secure_storage của chính máy này.
// Dữ liệu khuôn mặt không bao giờ rời khỏi máy, đây là điểm cộng về quyền riêng tư khi thuyết trình.
import 'dart:convert';

import '../../../core/storage/secure_storage.dart';

class FaceTemplate {
  const FaceTemplate({required this.userId, required this.userName, required this.embedding});
  final String userId;
  final String userName;
  final List<double> embedding;
}

class FaceStorage {
  FaceStorage._();
  static final _store = SecureStore.instance;

  /// Tên người đã đăng ký khuôn mặt trên máy này (null = chưa bật).
  static Future<String?> enrolledUserName() async {
    final token = await _store.read(SecureStore.kFaceToken);
    final template = await _store.read(SecureStore.kFaceTemplate);
    if (token == null || template == null) return null;
    return _store.read(SecureStore.kFaceUserName);
  }

  static Future<void> save(FaceTemplate t, String faceToken) async {
    await _store.write(SecureStore.kFaceTemplate, jsonEncode(t.embedding));
    await _store.write(SecureStore.kFaceUserId, t.userId);
    await _store.write(SecureStore.kFaceUserName, t.userName);
    await _store.write(SecureStore.kFaceToken, faceToken);
  }

  static Future<FaceTemplate?> load() async {
    final raw = await _store.read(SecureStore.kFaceTemplate);
    final userId = await _store.read(SecureStore.kFaceUserId);
    if (raw == null || userId == null) return null;
    final list = (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
    return FaceTemplate(userId: userId, userName: await _store.read(SecureStore.kFaceUserName) ?? '', embedding: list);
  }

  static Future<String?> faceToken() => _store.read(SecureStore.kFaceToken);

  static Future<void> clear() => _store.clearFace();
}
