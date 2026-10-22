// State cảnh báo: bộ lọc (con / loại / chưa đọc), danh sách theo bộ lọc, số chưa đọc cho badge chuông.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/alerts_api.dart';

class AlertFilter {
  const AlertFilter({this.childId, this.type, this.unreadOnly = false});
  final String? childId;
  final String? type;
  final bool unreadOnly;

  AlertFilter copyWith({String? childId, String? type, bool? unreadOnly, bool clearChild = false, bool clearType = false}) =>
      AlertFilter(
        childId: clearChild ? null : (childId ?? this.childId),
        type: clearType ? null : (type ?? this.type),
        unreadOnly: unreadOnly ?? this.unreadOnly,
      );
}

final alertFilterProvider = NotifierProvider<AlertFilterNotifier, AlertFilter>(AlertFilterNotifier.new);

class AlertFilterNotifier extends Notifier<AlertFilter> {
  @override
  AlertFilter build() => const AlertFilter();
  void set(AlertFilter f) => state = f;
}

final alertsProvider = AsyncNotifierProvider<AlertsNotifier, AlertPage>(AlertsNotifier.new);

class AlertsNotifier extends AsyncNotifier<AlertPage> {
  AlertsApi get _api => ref.read(alertsApiProvider);

  @override
  Future<AlertPage> build() {
    final f = ref.watch(alertFilterProvider);
    return _api.list(childId: f.childId, type: f.type, unread: f.unreadOnly);
  }

  Future<void> refresh() async => ref.invalidateSelf();

  Future<void> markRead(String id) async {
    await _api.markRead(id);
    ref.invalidateSelf();
  }

  Future<void> markAllRead() async {
    await _api.markAllRead();
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await _api.delete(id);
    ref.invalidateSelf();
  }

  Future<void> removeRead() async {
    await _api.deleteRead();
    ref.invalidateSelf();
  }
}

/// Số cảnh báo chưa đọc (badge trên chuông).
final unreadCountProvider = Provider<int>((ref) => ref.watch(alertsProvider).value?.unreadCount ?? 0);
