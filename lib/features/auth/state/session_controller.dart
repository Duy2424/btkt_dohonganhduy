// Trạng thái phiên toàn app (Riverpod Notifier viết tay): máy đang ở chế độ nào (phụ huynh / con),
// ai đang đăng nhập, máy con đã ghép chưa. Router đọc trạng thái này để điều hướng theo role.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_events.dart';
import '../../../core/platform/native_channel.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/storage/secure_storage.dart';
import '../../child_mode/services/location_service.dart';
import '../data/auth_api.dart';
import '../data/models/app_user.dart';

class SessionState {
  const SessionState({this.ready = false, this.mode, this.user, this.childPaired = false});

  /// Đã đọc xong storage lúc mở app chưa (chưa xong → màn splash).
  final bool ready;
  final AppMode? mode;
  final AppUser? user;
  final bool childPaired;

  bool get loggedIn => user != null;

  SessionState copyWith({bool? ready, AppMode? mode, AppUser? user, bool clearUser = false, bool? childPaired, bool clearMode = false}) =>
      SessionState(
        ready: ready ?? this.ready,
        mode: clearMode ? null : (mode ?? this.mode),
        user: clearUser ? null : (user ?? this.user),
        childPaired: childPaired ?? this.childPaired,
      );
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  final _store = SecureStore.instance;
  StreamSubscription<AuthEvent>? _sub;

  @override
  SessionState build() {
    _sub = AuthEvents.stream.listen((event) {
      if (event == AuthEvent.sessionExpired && state.loggedIn) logout(callServer: false);
      if (event == AuthEvent.deviceUnpaired && state.childPaired) unpairChild();
    });
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(_bootstrap);
    return const SessionState();
  }

  AuthApi get _api => ref.read(authApiProvider);

  Future<void> _bootstrap() async {
    final mode = LocalPrefs.instance.mode;
    if (mode == AppMode.child) {
      final token = await _store.read(SecureStore.kDeviceToken);
      if (token == null) await _stopChildServices(); // dọn dịch vụ còn sót nếu máy đã bị huỷ ghép
      state = SessionState(ready: true, mode: mode, childPaired: token != null);
      return;
    }
    if (mode == AppMode.parent && await _store.read(SecureStore.kRefresh) != null) {
      try {
        final user = await _api.me(); // interceptor tự refresh nếu access token hết hạn
        state = SessionState(ready: true, mode: mode, user: user);
        return;
      } catch (_) {
        // Mất mạng hoặc phiên hết hạn → về màn đăng nhập (vẫn còn đăng nhập khuôn mặt nếu đã bật)
      }
    }
    state = SessionState(ready: true, mode: mode);
  }

  Future<void> chooseMode(AppMode mode) async {
    await LocalPrefs.instance.setMode(mode);
    state = state.copyWith(mode: mode);
  }

  /// Quay lại màn chọn loại máy.
  Future<void> resetMode() async {
    if (state.mode == AppMode.child) await _stopChildServices();
    await LocalPrefs.instance.setMode(null);
    state = SessionState(ready: true, childPaired: state.childPaired);
  }

  Future<void> completeLogin(AuthResult result) async {
    await _store.saveSession(result.accessToken, result.refreshToken);
    if (result.faceToken != null) await _store.write(SecureStore.kFaceToken, result.faceToken);
    state = state.copyWith(user: result.user, mode: AppMode.parent);
  }

  void updateUser(AppUser user) => state = state.copyWith(user: user);

  Future<void> logout({bool callServer = true}) async {
    final refresh = await _store.read(SecureStore.kRefresh);
    if (callServer && refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {}
    }
    await _store.clearSession();
    state = state.copyWith(clearUser: true);
  }

  Future<void> pairedAsChild(String deviceToken) async {
    await _store.write(SecureStore.kDeviceToken, deviceToken);
    state = state.copyWith(childPaired: true, mode: AppMode.child);
  }

  /// Máy con bị huỷ ghép: xoá token, tắt dịch vụ vị trí và khoá máy, xoá lịch khoá đã lưu trên máy
  /// (nếu không, máy vẫn bị khoá theo lịch cũ dù đã thôi quản lý).
  Future<void> unpairChild() async {
    await _store.write(SecureStore.kDeviceToken, null);
    await _stopChildServices();
    state = state.copyWith(childPaired: false);
  }

  Future<void> _stopChildServices() async {
    LocationService.stop();
    await NativeChannel.stopLockService();
  }
}
