// Widget test: render thật các màn chính (đăng nhập, đăng ký, thẻ con, thống kê admin, lịch khoá)
// để bắt lỗi giao diện khi chạy (tràn layout, null) và kiểm tra validate ngay tại ô nhập.
import 'package:btkt_dohonganhduy/app/theme/app_theme.dart';
import 'package:btkt_dohonganhduy/core/storage/local_prefs.dart';
import 'package:btkt_dohonganhduy/features/admin/data/admin_api.dart';
import 'package:btkt_dohonganhduy/features/admin/ui/screens/admin_stats_screen.dart';
import 'package:btkt_dohonganhduy/features/auth/ui/screens/login_screen.dart';
import 'package:btkt_dohonganhduy/features/auth/ui/screens/register_screen.dart';
import 'package:btkt_dohonganhduy/features/children/data/models/child_profile.dart';
import 'package:btkt_dohonganhduy/features/children/ui/widgets/child_card.dart';
import 'package:btkt_dohonganhduy/features/lock_schedules/data/lock_schedules_api.dart';
import 'package:btkt_dohonganhduy/features/lock_schedules/ui/widgets/lock_schedule_list.dart';
import 'package:btkt_dohonganhduy/features/onboarding/ui/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(Widget child, {List overrides = const []}) => ProviderScope(
      overrides: [...overrides],
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await LocalPrefs.init();
  });

  testWidgets('Onboarding hiện 2 lựa chọn loại máy', (tester) async {
    await tester.pumpWidget(wrap(const OnboardingScreen()));
    expect(find.text('Máy phụ huynh / nhân viên'), findsOneWidget);
    expect(find.text('Máy của con'), findsOneWidget);
  });

  testWidgets('Đăng nhập: bỏ trống → báo lỗi ngay tại ô', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên đăng nhập'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập bằng khuôn mặt'), findsNothing); // máy chưa bật khuôn mặt
  });

  testWidgets('Đăng ký: mật khẩu yếu & nhập lại không khớp bị chặn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    await tester.pumpWidget(wrap(const RegisterScreen()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Đỗ Hồng Anh Duy');
    await tester.enterText(fields.at(1), 'duy_01');
    await tester.enterText(fields.at(2), 'duy@gmail.com');
    await tester.enterText(fields.at(4), 'abcdefgh');
    await tester.enterText(fields.at(5), 'khac');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pump();
    expect(find.text('Mật khẩu phải có chữ số'), findsOneWidget);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Thẻ con: tên, "Ở trường", pin, trực tuyến', (tester) async {
    final child = ChildProfile.fromJson({
      'id': 'c1',
      'name': 'Bé An',
      'avatarColor': '#0EA5E9',
      'lastLocation': {'lat': 10.77, 'lng': 106.70, 'accuracy': 12, 'battery': 12, 'at': DateTime.now().toIso8601String()},
      'device': {'id': 'd1', 'name': 'Điện thoại của An', 'batteryLevel': 12, 'online': true, 'lastSeenAt': DateTime.now().toIso8601String()},
      'place': {'type': 'school', 'name': 'Ở trường'},
      'latestAlert': {'type': 'low_battery', 'level': 'warning', 'title': 'Pin yếu', 'createdAt': DateTime.now().toIso8601String()},
    });
    await tester.pumpWidget(wrap(Scaffold(body: ChildCard(child: child))));
    expect(find.text('Bé An'), findsOneWidget);
    expect(find.text('Ở trường'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('Trực tuyến'), findsOneWidget);
  });

  testWidgets('Thống kê admin hiển thị số liệu', (tester) async {
    final stats = AdminStats({
      'usersByRole': {'admin': 1, 'staff': 2, 'parent': 7},
      'usersByStatus': {'locked': 1},
      'devices': {'online15m': 3, 'total': 4},
      'alertsToday': 5,
      'tickets': {'open': 2, 'inProgress': 1},
    });
    await tester.pumpWidget(wrap(const Scaffold(body: AdminStatsScreen()),
        overrides: [adminStatsProvider.overrideWith((ref) async => stats)]));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
  });

  testWidgets('Lịch khoá rỗng → thông báo hướng dẫn', (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(body: LockScheduleList(childId: 'c1')),
        overrides: [lockSchedulesProvider('c1').overrideWith((ref) async => <LockSchedule>[])]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có lịch khoá máy'), findsOneWidget);
  });

  testWidgets('Lịch khoá có dữ liệu → nhãn "Đang hiệu lực"', (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(body: LockScheduleList(childId: 'c2')), overrides: [
      lockSchedulesProvider('c2').overrideWith((ref) async => [
            const LockSchedule(
              id: 'l1', childId: 'c2', name: 'Giờ ngủ', daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
              startTime: '21:30', endTime: '06:30', activeNow: true,
            ),
          ]),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Giờ ngủ'), findsOneWidget);
    expect(find.text('Đang hiệu lực'), findsOneWidget);
  });
}
