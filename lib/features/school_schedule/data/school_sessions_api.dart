// Model và API thời khoá biểu (buổi học) của con: /api/school-sessions?childId= (CRUD), dữ liệu cho "Giờ học an toàn".
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

final schoolSessionsApiProvider = Provider<SchoolSessionsApi>((ref) => SchoolSessionsApi(ref.watch(apiClientProvider)));

final schoolSessionsProvider = FutureProvider.family<List<SchoolSession>, String>(
  (ref, childId) => ref.watch(schoolSessionsApiProvider).list(childId),
);

class SchoolSession {
  const SchoolSession({
    required this.id,
    required this.childId,
    required this.geofenceId,
    required this.geofenceName,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    this.label = '',
    this.graceMinutes = 15,
    this.outsideToleranceMinutes = 5,
    this.active = true,
  });

  final String id;
  final String childId;
  final String geofenceId;
  final String geofenceName;
  final List<int> daysOfWeek;
  final String startTime;
  final String endTime;
  final String label;
  final int graceMinutes;
  final int outsideToleranceMinutes;
  final bool active;

  factory SchoolSession.fromJson(Map<String, dynamic> j) => SchoolSession(
        id: j['id'] as String,
        childId: j['childId'] as String,
        geofenceId: j['geofenceId'] as String,
        geofenceName: (j['geofenceName'] ?? '') as String,
        daysOfWeek: (j['daysOfWeek'] as List).map((e) => (e as num).toInt()).toList(),
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
        label: (j['label'] ?? '') as String,
        graceMinutes: (j['graceMinutes'] as num?)?.toInt() ?? 15,
        outsideToleranceMinutes: (j['outsideToleranceMinutes'] as num?)?.toInt() ?? 5,
        active: (j['active'] ?? true) as bool,
      );
}

class SchoolSessionsApi {
  SchoolSessionsApi(this._api);
  final ApiClient _api;

  Future<List<SchoolSession>> list(String childId) async {
    final d = await _api.get('/api/school-sessions', query: {'childId': childId});
    return (d['items'] as List).map((e) => SchoolSession.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> create(Map<String, dynamic> body) => _api.post('/api/school-sessions', data: body);
  Future<void> update(String id, Map<String, dynamic> body) => _api.patch('/api/school-sessions/$id', data: body);
  Future<void> delete(String id) => _api.delete('/api/school-sessions/$id');
}
