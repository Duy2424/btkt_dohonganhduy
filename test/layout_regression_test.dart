// Test hồi quy giao diện phát hiện khi chạy thử trên Xiaomi: màn chi tiết con trắng trơn và hộp thoại xác nhận
// (nút FilledButton có minimumSize rộng vô hạn khi nằm trong ListTile / hộp thoại).
import 'package:btkt_dohonganhduy/app/theme/app_theme.dart';
import 'package:btkt_dohonganhduy/core/storage/local_prefs.dart';
import 'package:btkt_dohonganhduy/features/children/data/models/child_profile.dart';
import 'package:btkt_dohonganhduy/features/children/state/children_providers.dart';
import 'package:btkt_dohonganhduy/features/children/ui/screens/child_detail_screen.dart';
import 'package:btkt_dohonganhduy/shared/widgets/feedback.dart';
import 'package:btkt_dohonganhduy/core/network/api_exception.dart';
import 'package:btkt_dohonganhduy/core/network/dio_client.dart';
import 'package:btkt_dohonganhduy/features/geofences/data/geofences_api.dart';
import 'package:btkt_dohonganhduy/features/geofences/ui/screens/geofence_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeChildren extends ChildrenNotifier {
  @override
  Future<List<ChildProfile>> build() async => [
        ChildProfile.fromJson({'id': 'c1', 'name': 'Bao An', 'schoolName': 'THCS Le Loi', 'birthYear': 2015}),
      ];
}

class _FailingGeofencesApi extends GeofencesApi {
  _FailingGeofencesApi() : super(ApiClient(Dio()));
  @override
  Future<void> delete(String id) async =>
      throw ApiException('GEOFENCE_IN_USE', 'Vùng đang gắn với thời khoá biểu', statusCode: 409);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPrefs.init();
  });

  testWidgets('Chi tiết con (chưa ghép máy) hiển thị đủ nội dung', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [childrenProvider.overrideWith(_FakeChildren.new)],
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.light(), home: const ChildDetailScreen(childId: 'c1')),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Chưa ghép điện thoại'), findsOneWidget);
    expect(find.text('Ghép'), findsOneWidget);
    expect(find.text('Hôm nay con nghỉ học'), findsOneWidget);
  });

  testWidgets('Hộp thoại xác nhận xoá dựng được và trả về true khi bấm Xoá', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmDialog(context, title: 'Xoá?', message: 'Không hoàn tác được'),
          child: const Text('mở'),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Xoá vùng trường đang dùng → SnackBar báo lý do từ server', (tester) async {
    const fence = Geofence(id: 'g1', childId: 'c1', name: 'Trường', type: 'school', lat: 10.7, lng: 106.7, radiusM: 150);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        geofencesApiProvider.overrideWithValue(_FailingGeofencesApi()),
        geofencesProvider('c1').overrideWith((ref) async => [fence]),
      ],
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.light(), home: const GeofenceListScreen(childId: 'c1')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Vùng đang gắn với thời khoá biểu'), findsOneWidget);
  });
}
