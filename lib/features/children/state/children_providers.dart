// State danh sách con (AsyncNotifier viết tay): tải, làm mới, thêm / sửa / xoá,
// và cập nhật vị trí realtime khi socket báo "location:new".
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/children_api.dart';
import '../data/models/child_profile.dart';

final childrenProvider = AsyncNotifierProvider<ChildrenNotifier, List<ChildProfile>>(ChildrenNotifier.new);

class ChildrenNotifier extends AsyncNotifier<List<ChildProfile>> {
  ChildrenApi get _api => ref.read(childrenApiProvider);

  @override
  Future<List<ChildProfile>> build() => _api.list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_api.list);
  }

  Future<ChildProfile> create(Map<String, dynamic> body) async {
    final child = await _api.create(body);
    await refresh();
    return child;
  }

  Future<void> edit(String id, Map<String, dynamic> body) async {
    await _api.update(id, body);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _api.delete(id);
    await refresh();
  }

  /// Socket đẩy vị trí mới → thay đúng 1 con trong danh sách.
  void applyLive(String childId, GeoPoint? loc, DeviceSummary? device) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final c in list) c.id == childId ? c.withLive(loc, device) : c]);
  }
}

/// Con đang được chọn ở các màn Bản đồ / Lịch (null = con đầu tiên).
final selectedChildIdProvider = NotifierProvider<SelectedChild, String?>(SelectedChild.new);

class SelectedChild extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

/// Con đang chọn (tự lấy con đầu tiên nếu chưa chọn).
final selectedChildProvider = Provider<ChildProfile?>((ref) {
  final list = ref.watch(childrenProvider).value ?? const [];
  if (list.isEmpty) return null;
  final id = ref.watch(selectedChildIdProvider);
  return list.firstWhere((c) => c.id == id, orElse: () => list.first);
});
