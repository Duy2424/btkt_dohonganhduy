// Lưu cấu hình không nhạy cảm bằng shared_preferences: chế độ máy (phụ huynh / con), mã định danh máy,
// số lần sai khuôn mặt, con đang chọn ở các màn lịch.
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { parent, child }

class LocalPrefs {
  LocalPrefs._(this._prefs);
  static late LocalPrefs instance;

  final SharedPreferences _prefs;

  static Future<void> init() async {
    instance = LocalPrefs._(await SharedPreferences.getInstance());
  }

  static const _kMode = 'app_mode';
  static const _kDeviceId = 'device_id';
  static const _kFaceFails = 'face_fail_count';
  static const _kSelectedChild = 'selected_child_id';

  AppMode? get mode => switch (_prefs.getString(_kMode)) {
        'parent' => AppMode.parent,
        'child' => AppMode.child,
        _ => null,
      };

  Future<void> setMode(AppMode? mode) =>
      mode == null ? _prefs.remove(_kMode) : _prefs.setString(_kMode, mode.name);

  /// Mã định danh ngẫu nhiên của máy này (dùng cho "máy tin cậy" khi đăng nhập khuôn mặt).
  String get deviceId {
    var id = _prefs.getString(_kDeviceId);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  int get faceFailCount => _prefs.getInt(_kFaceFails) ?? 0;
  Future<void> setFaceFailCount(int v) => _prefs.setInt(_kFaceFails, v);

  String? get selectedChildId => _prefs.getString(_kSelectedChild);
  Future<void> setSelectedChildId(String? id) =>
      id == null ? _prefs.remove(_kSelectedChild) : _prefs.setString(_kSelectedChild, id);
}
