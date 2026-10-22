// Model + API lịch khoá máy: /api/lock-schedules?childId= (CRUD, bật/tắt nhanh) + danh sách app trên máy con.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

final lockSchedulesApiProvider = Provider<LockSchedulesApi>((ref) => LockSchedulesApi(ref.watch(apiClientProvider)));

final lockSchedulesProvider = FutureProvider.family<List<LockSchedule>, String>(
  (ref, childId) => ref.watch(lockSchedulesApiProvider).list(childId),
);

/// App có icon trên máy con (máy con gửi lên), để chọn "app được phép" khi khoá.
final childAppsProvider = FutureProvider.family<List<InstalledApp>, String>(
  (ref, childId) => ref.watch(lockSchedulesApiProvider).childApps(childId),
);

class InstalledApp {
  const InstalledApp(this.packageName, this.label);
  final String packageName;
  final String label;
}

class LockSchedule {
  const LockSchedule({
    required this.id,
    required this.childId,
    required this.name,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    this.allowedPackages = const [],
    this.enabled = true,
    this.activeNow = false,
  });

  final String id;
  final String childId;
  final String name;
  final List<int> daysOfWeek;
  final String startTime;
  final String endTime;
  final List<String> allowedPackages;
  final bool enabled;
  final bool activeNow;

  factory LockSchedule.fromJson(Map<String, dynamic> j) => LockSchedule(
        id: j['id'] as String,
        childId: j['childId'] as String,
        name: j['name'] as String,
        daysOfWeek: (j['daysOfWeek'] as List).map((e) => (e as num).toInt()).toList(),
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
        allowedPackages: ((j['allowedPackages'] as List?) ?? const []).cast<String>(),
        enabled: (j['enabled'] ?? true) as bool,
        activeNow: (j['activeNow'] ?? false) as bool,
      );
}

class LockSchedulesApi {
  LockSchedulesApi(this._api);
  final ApiClient _api;

  Future<List<LockSchedule>> list(String childId) async {
    final d = await _api.get('/api/lock-schedules', query: {'childId': childId});
    return (d['items'] as List).map((e) => LockSchedule.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> create(Map<String, dynamic> body) => _api.post('/api/lock-schedules', data: body);
  Future<void> update(String id, Map<String, dynamic> body) => _api.patch('/api/lock-schedules/$id', data: body);
  Future<void> delete(String id) => _api.delete('/api/lock-schedules/$id');

  Future<List<InstalledApp>> childApps(String childId) async {
    final d = await _api.get('/api/devices/child/$childId/apps');
    return (d['items'] as List)
        .map((e) => InstalledApp(e['packageName'] as String, (e['label'] ?? e['packageName']) as String))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }
}
