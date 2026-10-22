// Gọi API hồ sơ con: /api/children (CRUD, mã ghép QR, ngày nghỉ học) + vị trí /api/children/:id/locations.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'models/child_profile.dart';

final childrenApiProvider = Provider<ChildrenApi>((ref) => ChildrenApi(ref.watch(apiClientProvider)));

class PairingCode {
  const PairingCode({required this.qrPayload, required this.expiresAt, required this.ttlSeconds});
  final String qrPayload;
  final DateTime expiresAt;
  final int ttlSeconds;
}

class ChildrenApi {
  ChildrenApi(this._api);
  final ApiClient _api;

  Future<List<ChildProfile>> list({String search = ''}) async {
    final d = await _api.get('/api/children', query: {'search': search});
    return (d['items'] as List).map((e) => ChildProfile.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<ChildProfile> get(String id) async =>
      ChildProfile.fromJson(Map<String, dynamic>.from(await _api.get('/api/children/$id') as Map));

  Future<ChildProfile> create(Map<String, dynamic> body) async =>
      ChildProfile.fromJson(Map<String, dynamic>.from(await _api.post('/api/children', data: body) as Map));

  Future<ChildProfile> update(String id, Map<String, dynamic> body) async =>
      ChildProfile.fromJson(Map<String, dynamic>.from(await _api.patch('/api/children/$id', data: body) as Map));

  Future<void> delete(String id) => _api.delete('/api/children/$id');

  Future<PairingCode> createPairingCode(String id) async {
    final d = await _api.post('/api/children/$id/pairing-code');
    return PairingCode(
      qrPayload: d['qrPayload'] as String,
      expiresAt: DateTime.parse(d['expiresAt'] as String).toLocal(),
      ttlSeconds: (d['ttlSeconds'] as num).toInt(),
    );
  }

  Future<void> addOffDate(String id, String date) => _api.post('/api/children/$id/off-dates', data: {'date': date});
  Future<void> removeOffDate(String id, String date) => _api.delete('/api/children/$id/off-dates', data: {'date': date});

  Future<List<GeoPoint>> history(String id, String date) async {
    final d = await _api.get('/api/children/$id/locations', query: {'date': date});
    return (d['points'] as List).map(GeoPoint.fromJson).whereType<GeoPoint>().toList();
  }

  Future<(GeoPoint?, DeviceSummary?)> latest(String id) async {
    final d = await _api.get('/api/children/$id/locations/latest');
    return (GeoPoint.fromJson(d['lastLocation']), DeviceSummary.fromJson(d['device']));
  }
}
