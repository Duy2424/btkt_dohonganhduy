// Model + API vùng an toàn: /api/geofences?childId= (CRUD).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

final geofencesApiProvider = Provider<GeofencesApi>((ref) => GeofencesApi(ref.watch(apiClientProvider)));

/// Danh sách vùng của 1 con. Làm mới bằng ref.invalidate(geofencesProvider(childId)).
final geofencesProvider = FutureProvider.family<List<Geofence>, String>(
  (ref, childId) => ref.watch(geofencesApiProvider).list(childId),
);

class Geofence {
  const Geofence({
    required this.id,
    required this.childId,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.radiusM,
    this.notifyEnter = true,
    this.notifyExit = true,
    this.active = true,
  });

  final String id;
  final String childId;
  final String name;
  final String type; // home | school | other
  final double lat;
  final double lng;
  final double radiusM;
  final bool notifyEnter;
  final bool notifyExit;
  final bool active;

  factory Geofence.fromJson(Map<String, dynamic> j) => Geofence(
        id: j['id'] as String,
        childId: j['childId'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        lat: (j['center']['lat'] as num).toDouble(),
        lng: (j['center']['lng'] as num).toDouble(),
        radiusM: (j['radiusM'] as num).toDouble(),
        notifyEnter: (j['notifyEnter'] ?? true) as bool,
        notifyExit: (j['notifyExit'] ?? true) as bool,
        active: (j['active'] ?? true) as bool,
      );
}

class GeofencesApi {
  GeofencesApi(this._api);
  final ApiClient _api;

  Future<List<Geofence>> list(String childId) async {
    final d = await _api.get('/api/geofences', query: {'childId': childId});
    return (d['items'] as List).map((e) => Geofence.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> create(Map<String, dynamic> body) => _api.post('/api/geofences', data: body);
  Future<void> update(String id, Map<String, dynamic> body) => _api.patch('/api/geofences/$id', data: body);
  Future<void> delete(String id) => _api.delete('/api/geofences/$id');
}
