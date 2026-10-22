// API trang quản trị: thống kê + CRUD người dùng (tìm kiếm, lọc role/status, khoá/mở, xoá mềm).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/data/models/app_user.dart';

final adminApiProvider = Provider<AdminApi>((ref) => AdminApi(ref.watch(apiClientProvider)));

final adminStatsProvider = FutureProvider<AdminStats>((ref) => ref.watch(adminApiProvider).stats());

class UserQuery {
  const UserQuery({this.search = '', this.role, this.status});
  final String search;
  final String? role;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is UserQuery && other.search == search && other.role == role && other.status == status;
  @override
  int get hashCode => Object.hash(search, role, status);
}

final adminUsersProvider = FutureProvider.family<List<AppUser>, UserQuery>(
  (ref, q) => ref.watch(adminApiProvider).listUsers(q),
);

class AdminStats {
  const AdminStats(this.raw);
  final Map<String, dynamic> raw;

  int _n(String a, [String? b]) {
    final v = b == null ? raw[a] : (raw[a] as Map?)?[b];
    return (v as num?)?.toInt() ?? 0;
  }

  int get admins => _n('usersByRole', 'admin');
  int get staff => _n('usersByRole', 'staff');
  int get parents => _n('usersByRole', 'parent');
  int get locked => _n('usersByStatus', 'locked');
  int get pending => _n('usersByStatus', 'pending');
  int get devicesOnline => _n('devices', 'online15m');
  int get devicesTotal => _n('devices', 'total');
  int get alertsToday => _n('alertsToday');
  int get ticketsOpen => _n('tickets', 'open');
  int get ticketsInProgress => _n('tickets', 'inProgress');
}

class AdminApi {
  AdminApi(this._api);
  final ApiClient _api;

  Future<AdminStats> stats() async => AdminStats(Map<String, dynamic>.from(await _api.get('/api/admin/stats') as Map));

  Future<List<AppUser>> listUsers(UserQuery q) async {
    final d = await _api.get('/api/admin/users', query: {'search': q.search, 'role': q.role, 'status': q.status, 'limit': 100});
    return (d['items'] as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createUser(Map<String, dynamic> body) => _api.post('/api/admin/users', data: body);
  Future<void> updateUser(String id, Map<String, dynamic> body) => _api.patch('/api/admin/users/$id', data: body);
  Future<void> setStatus(String id, String status) => _api.patch('/api/admin/users/$id/status', data: {'status': status});
  Future<void> deleteUser(String id) => _api.delete('/api/admin/users/$id');
}
