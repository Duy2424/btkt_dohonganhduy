// Khung màn phụ huynh: bottom nav 4 tab (Tổng quan · Bản đồ · Lịch · Cài đặt) + chuông cảnh báo có badge.
// Giữ kết nối Socket.IO (realtimeProvider) sống trong suốt thời gian phụ huynh dùng app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/socket_service.dart';
import '../../../alerts/ui/widgets/alert_bell.dart';
import '../../../map/ui/screens/map_screen.dart';
import '../../../school_schedule/ui/screens/schedule_screen.dart';
import 'overview_screen.dart';
import 'settings_screen.dart';

class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _index = 0;
  static const _titles = ['Tổng quan', 'Bản đồ', 'Lịch của con', 'Cài đặt'];

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(realtimeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          Tooltip(
            message: connected ? 'Đang nhận vị trí realtime' : 'Mất kết nối realtime — tự cập nhật mỗi 30 giây',
            child: Icon(Icons.circle, size: 10, color: connected ? Colors.green : Colors.grey),
          ),
          const AlertBell(),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [OverviewScreen(), MapScreen(), ScheduleScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Bản đồ'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Lịch'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }
}
