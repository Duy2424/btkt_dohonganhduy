// Model + API cảnh báo của phụ huynh: lọc theo con / loại / chưa đọc, đánh dấu đọc, xoá.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../children/data/models/child_profile.dart';

final alertsApiProvider = Provider<AlertsApi>((ref) => AlertsApi(ref.watch(apiClientProvider)));

class AlertItem {
  const AlertItem({
    required this.id,
    required this.childId,
    required this.childName,
    required this.type,
    required this.level,
    required this.title,
    required this.message,
    this.location,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String childId;
  final String childName;
  final String type;
  final String level;
  final String title;
  final String message;
  final GeoPoint? location;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get unread => readAt == null;

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: j['id'] as String,
        childId: j['childId'] as String,
        childName: (j['childName'] ?? '') as String,
        type: j['type'] as String,
        level: (j['level'] ?? 'info') as String,
        title: (j['title'] ?? '') as String,
        message: (j['message'] ?? '') as String,
        location: GeoPoint.fromJson(j['location']),
        readAt: parseDate(j['readAt']),
        createdAt: parseDate(j['createdAt']),
      );
}

class AlertPage {
  const AlertPage(this.items, this.unreadCount);
  final List<AlertItem> items;
  final int unreadCount;
}

class AlertsApi {
  AlertsApi(this._api);
  final ApiClient _api;

  Future<AlertPage> list({String? childId, String? type, bool unread = false}) async {
    final d = await _api.get('/api/alerts', query: {
      'childId': childId,
      'type': type,
      'unread': unread ? 'true' : null,
      'limit': 100,
    });
    final items = (d['items'] as List).map((e) => AlertItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return AlertPage(items, (d['unreadCount'] as num).toInt());
  }

  Future<void> markRead(String id) => _api.patch('/api/alerts/$id/read');
  Future<void> markAllRead() => _api.patch('/api/alerts/read-all');
  Future<void> delete(String id) => _api.delete('/api/alerts/$id');
  Future<void> deleteRead() => _api.delete('/api/alerts/read');
}
