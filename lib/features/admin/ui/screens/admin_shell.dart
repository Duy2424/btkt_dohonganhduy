// Trang quản trị (role admin): 3 tab Thống kê · Người dùng · Ticket.
// Admin không xem được vị trí / dữ liệu của trẻ (quyền riêng tư theo role).
import 'package:flutter/material.dart';

import '../../../../shared/widgets/account_menu.dart';
import '../../../tickets/ui/widgets/ticket_list_view.dart';
import 'admin_stats_screen.dart';
import 'admin_users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  static const _titles = ['Thống kê', 'Người dùng', 'Tất cả ticket'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quản trị · ${_titles[_index]}'), actions: const [AccountMenu()]),
      body: IndexedStack(
        index: _index,
        children: const [AdminStatsScreen(), AdminUsersScreen(), TicketListView()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Thống kê'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Người dùng'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Ticket'),
        ],
      ),
    );
  }
}
