// Model + API thiết bị phía phụ huynh: danh sách máy con đã ghép, đổi tên, huỷ ghép, "Định vị ngay".
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../children/data/models/child_profile.dart';

final devicesApiProvider = Provider<DevicesApi>((ref) => DevicesApi(ref.watch(apiClientProvider)));

final devicesProvider = FutureProvider<List<DeviceInfo>>((ref) => ref.watch(devicesApiProvider).list());

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.model,
    required this.childId,
    required this.childName,
    required this.childColor,
    this.androidVersion = '',
    this.batteryLevel,
    this.lastSeenAt,
    this.online = false,
    this.permissions = const {},
  });

  final String id;
  final String name;
  final String model;
  final String childId;
  final String childName;
  final String childColor;
  final String androidVersion;
  final int? batteryLevel;
  final DateTime? lastSeenAt;
  final bool online;
  final Map<String, dynamic> permissions;

  factory DeviceInfo.fromJson(Map<String, dynamic> j) => DeviceInfo(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        childId: j['childId'] as String,
        childName: (j['childName'] ?? '') as String,
        childColor: (j['childColor'] ?? '#14B8A6') as String,
        androidVersion: (j['androidVersion'] ?? '') as String,
        batteryLevel: (j['batteryLevel'] as num?)?.toInt(),
        lastSeenAt: parseDate(j['lastSeenAt']),
        online: (j['online'] ?? false) as bool,
        permissions: Map<String, dynamic>.from((j['permissions'] as Map?) ?? const {}),
      );
}

class DevicesApi {
  DevicesApi(this._api);
  final ApiClient _api;

  Future<List<DeviceInfo>> list() async {
    final d = await _api.get('/api/devices');
    return (d['items'] as List).map((e) => DeviceInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> rename(String id, String name) => _api.patch('/api/devices/$id', data: {'name': name});
  Future<void> unpair(String id) => _api.delete('/api/devices/$id');
  Future<void> locateNow(String id) => _api.post('/api/devices/$id/locate-now');
}
