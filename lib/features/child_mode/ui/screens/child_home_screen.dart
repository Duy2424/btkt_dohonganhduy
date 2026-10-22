// Màn hình chính của máy con: banner minh bạch (bố mẹ thấy được gì), trạng thái hiện tại (giờ học / giờ khoá / tự do),
// lịch hôm nay, nút SOS giữ 2 giây. Tự bật dịch vụ vị trí, gửi danh sách app, đồng bộ lịch khoá cho dịch vụ native.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/platform/native_channel.dart';
import '../../../../core/push/fcm_service.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/state/session_controller.dart';
import '../../data/child_device_api.dart';
import '../../services/location_service.dart';
import '../../services/permission_status.dart';
import '../widgets/leave_child_mode_dialog.dart';
import '../widgets/sos_button.dart';

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> with WidgetsBindingObserver {
  ChildConfig? _config;
  Object? _error;
  Timer? _refreshTimer;
  Timer? _clock;
  final _subs = <StreamSubscription<dynamic>>[];
  Map<String, bool> _perms = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
    // Lịch khoá làm mới mỗi 15 phút + khi nhận FCM config_changed
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) => _loadConfig());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    final bg = FlutterBackgroundService();
    _subs.add(bg.on('config_changed').listen((_) => _loadConfig()));
    _subs.add(bg.on('unpaired').listen((_) => _unpaired()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _clock?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConfig();
      PermissionStatusReader.report(ref).then((p) => mounted ? setState(() => _perms = p) : null);
    }
  }

  Future<void> _boot() async {
    await _loadConfig();
    _perms = await PermissionStatusReader.report(ref);
    if (_perms['location'] == true) await LocationService.start();
    final api = ref.read(childDeviceApiProvider);
    // Danh sách app có icon ngoài launcher → phụ huynh chọn "app được phép" khi khoá máy
    NativeChannel.getLaunchableApps().then((apps) {
      if (apps.isNotEmpty) api.sendApps(apps.map((a) => a.toJson()).toList()).catchError((_) {});
    });
    FcmService.token().then((t) {
      if (t != null) api.setFcmToken(t).catchError((_) {});
    });
    if (mounted) setState(() {});
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ref.read(childDeviceApiProvider).config();
      if (!mounted) return;
      setState(() {
        _config = config;
        _error = null;
      });
      // Dịch vụ native khoá máy (cần quyền "Truy cập dữ liệu sử dụng")
      if (await NativeChannel.hasUsageAccess()) {
        await NativeChannel.startLockService({'lockSchedules': config.lockSchedules, 'childName': config.childName});
      }
    } catch (e) {
      if (mounted && _config == null) setState(() => _error = e);
    }
  }

  void _unpaired() => ref.read(sessionProvider.notifier).unpairChild();

  Future<void> _sendSos() async {
    try {
      Position? p;
      try {
        p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
        );
      } catch (_) {}
      await ref.read(childDeviceApiProvider).sos(lat: p?.latitude, lng: p?.longitude, accuracy: p?.accuracy);
      if (mounted) showSuccess(context, 'Đã gửi SOS tới bố mẹ!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Trạng thái hiện tại: giờ khoá máy > giờ học > tự do.
  (String, Color, IconData) _currentStatus(ChildConfig c) {
    final now = DateTime.now();
    for (final l in c.lockSchedules) {
      final days = (l['daysOfWeek'] as List).map((e) => (e as num).toInt()).toList();
      if (AppDates.isWithinWindow(days, l['startTime'] as String, l['endTime'] as String, now)) {
        return ('Đang trong giờ khoá máy đến ${l['endTime']}', AppColors.danger, Icons.lock_clock);
      }
    }
    if (!c.offToday) {
      for (final s in c.todaySessions) {
        final cur = now.hour * 60 + now.minute;
        if (cur >= AppDates.toMinutes(s['startTime'] as String) && cur < AppDates.toMinutes(s['endTime'] as String)) {
          return ('Đang trong giờ học đến ${s['endTime']}', AppColors.info, Icons.school);
        }
      }
    }
    return ('Tự do', AppColors.success, Icons.sentiment_satisfied_alt);
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    if (c == null) {
      return Scaffold(
        body: _error == null ? const Center(child: CircularProgressIndicator()) : ErrorView(error: _error!, onRetry: _loadConfig),
      );
    }
    final (status, statusColor, statusIcon) = _currentStatus(c);
    final weekday = DateTime.now().weekday;
    final todayLocks = c.lockSchedules.where((l) => (l['daysOfWeek'] as List).contains(weekday)).toList();
    final missing = _perms.entries.where((e) => !e.value && e.key != 'batteryOptimization').length;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ChildAvatar(name: c.childName, color: c.childColor, radius: 18),
          const SizedBox(width: 12),
          Text('Chào ${c.childName}!'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Kiểm tra quyền',
            icon: Badge(isLabelVisible: missing > 0, label: Text('$missing'), child: const Icon(Icons.verified_user_outlined)),
            onPressed: () => context.push('/child/permissions'),
          ),
          IconButton(
            tooltip: 'Thoát chế độ con',
            icon: const Icon(Icons.logout),
            onPressed: () => showLeaveChildModeDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadConfig,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            InfoBanner(
              icon: Icons.visibility_outlined,
              text: 'Bố mẹ (${c.parentName}) thấy được: vị trí, pin, lịch khoá máy. ConAn không đọc tin nhắn hay cuộc gọi của con.',
            ),
            AppSpacing.gapMd,
            Card(
              color: statusColor.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(children: [
                  Icon(statusIcon, size: 44, color: statusColor),
                  AppSpacing.gapMd,
                  Expanded(child: Text(status, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: statusColor))),
                ]),
              ),
            ),
            const SectionHeader('Lịch hôm nay'),
            if (c.offToday) const Text('🏖️ Hôm nay con được nghỉ học'),
            if (!c.offToday && c.todaySessions.isEmpty && todayLocks.isEmpty) const Text('Hôm nay không có lịch nào 🎉'),
            for (final s in c.todaySessions)
              ListTile(
                leading: const Icon(Icons.school, color: AppColors.info, size: 32),
                title: Text('${s['label'] == '' ? 'Buổi học' : s['label']} · ${s['startTime']} – ${s['endTime']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: Text('${s['schoolName']}'),
              ),
            for (final l in todayLocks)
              ListTile(
                leading: const Icon(Icons.lock_clock, color: AppColors.danger, size: 32),
                title: Text('${l['name']} · ${l['startTime']} – ${l['endTime']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            AppSpacing.gapXl,
            Center(child: SosButton(onTriggered: _sendSos)),
          ],
        ),
      ),
    );
  }
}
