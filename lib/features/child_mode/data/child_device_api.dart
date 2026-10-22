// API của máy con (đăng nhập bằng token thiết bị "dev_…" nhận khi ghép QR): ghép, cấu hình, danh sách app, SOS, quyền.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

final childDeviceApiProvider = Provider<ChildDeviceApi>((ref) => ChildDeviceApi(ref.watch(apiClientProvider)));

class TodayItem {
  const TodayItem(this.title, this.start, this.end, {this.isLock = false});
  final String title;
  final String start;
  final String end;
  final bool isLock;
}

class ChildConfig {
  const ChildConfig(this.raw);
  final Map<String, dynamic> raw;

  String get childName => (raw['child']?['name'] ?? '') as String;
  String get childColor => (raw['child']?['avatarColor'] ?? '#14B8A6') as String;
  String get parentName => (raw['parentName'] ?? '') as String;
  bool get offToday => (raw['offToday'] ?? false) as bool;
  List<Map<String, dynamic>> get lockSchedules =>
      ((raw['lockSchedules'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get todaySessions =>
      ((raw['todaySessions'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class ChildDeviceApi {
  ChildDeviceApi(this._api);
  final ApiClient _api;

  /// Ghép bằng mã QR → trả về deviceToken (role child).
  Future<Map<String, dynamic>> pair({required String code, required String model, required String androidVersion, required String appVersion}) async =>
      Map<String, dynamic>.from(await _api.post('/api/devices/pair', auth: false, data: {
        'code': code,
        'model': model,
        'androidVersion': androidVersion,
        'appVersion': appVersion,
      }) as Map);

  Future<ChildConfig> config() async => ChildConfig(Map<String, dynamic>.from(await _api.get('/api/devices/me/config') as Map));

  Future<void> sendApps(List<Map<String, String>> apps) => _api.post('/api/devices/me/apps', data: {'apps': apps}, retry: true);

  Future<void> sos({double? lat, double? lng, double? accuracy}) =>
      _api.post('/api/devices/me/sos', data: {'lat': lat, 'lng': lng, 'accuracy': accuracy}, retry: true);

  /// Thoát chế độ con: server kiểm mật khẩu của bố mẹ, đúng thì huỷ ghép.
  Future<void> leave(String parentPassword) => _api.post('/api/devices/me/leave', data: {'password': parentPassword});

  Future<void> setFcmToken(String token) => _api.patch('/api/devices/me/fcm-token', data: {'token': token});

  Future<void> reportPermissions(Map<String, bool> permissions) =>
      _api.post('/api/devices/me/permission-status', data: {'permissions': permissions});
}
