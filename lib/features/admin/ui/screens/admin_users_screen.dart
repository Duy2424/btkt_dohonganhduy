// Tab "Người dùng" của admin (CRUD người dùng): tìm theo tên/email/username, lọc role & trạng thái,
// tạo mới, sửa / đổi role, khoá / mở khoá, xoá mềm (không xoá được chính mình).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/data/models/app_user.dart';
import '../../../auth/state/session_controller.dart';
import '../../data/admin_api.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  UserQuery _query = const UserQuery();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _action(AppUser u, String action) async {
    final api = ref.read(adminApiProvider);
    try {
      switch (action) {
        case 'edit':
          await context.push('/admin/users/edit', extra: u);
        case 'lock':
        case 'unlock':
          await api.setStatus(u.id, action == 'lock' ? 'locked' : 'active');
          if (mounted) showSuccess(context, action == 'lock' ? 'Đã khoá ${u.username}' : 'Đã mở khoá ${u.username}');
        case 'delete':
          final ok = await confirmDialog(context, title: 'Xoá ${u.fullName}?', message: 'Tài khoản sẽ bị vô hiệu hoá (xoá mềm).');
          if (!ok) return;
          await api.deleteUser(u.id);
          if (mounted) showSuccess(context, 'Đã xoá người dùng');
      }
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStatsProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).user;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: SearchField(
              hint: 'Tìm theo tên, email, username...',
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400),
                    () => setState(() => _query = UserQuery(search: v.trim(), role: _query.role, status: _query.status)));
              },
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              children: [
                for (final r in [null, 'admin', 'staff', 'parent'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(r == null ? 'Mọi vai trò' : Labels.role(r)),
                      selected: _query.role == r,
                      onSelected: (_) => setState(() => _query = UserQuery(search: _query.search, role: r, status: _query.status)),
                    ),
                  ),
                for (final s in ['pending', 'locked'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(Labels.userStatus(s)),
                      selected: _query.status == s,
                      onSelected: (on) => setState(() => _query = UserQuery(search: _query.search, role: _query.role, status: on ? s : null)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncListView<AppUser>(
              value: ref.watch(adminUsersProvider(_query)),
              onRefresh: () => ref.refresh(adminUsersProvider(_query).future),
              emptyMessage: 'Không tìm thấy người dùng nào',
              emptyIcon: Icons.person_search,
              itemBuilder: (context, u) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(u.fullName.isEmpty ? '?' : u.fullName.characters.first)),
                  title: Text(u.fullName),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('@${u.username} · ${u.email}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      StatusChip(label: Labels.role(u.role), color: Theme.of(context).colorScheme.primary),
                      StatusChip(
                        label: Labels.userStatus(u.status),
                        color: u.status == 'active' ? AppColors.success : u.status == 'locked' ? AppColors.danger : AppColors.warning,
                      ),
                    ]),
                  ]),
                  trailing: PopupMenuButton<String>(
                      onSelected: (v) => _action(u, v),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Sửa / đổi vai trò')),
                        if (u.id != me?.id)
                          PopupMenuItem(value: u.status == 'locked' ? 'unlock' : 'lock', child: Text(u.status == 'locked' ? 'Mở khoá' : 'Khoá tài khoản')),
                        if (u.id != me?.id)
                          const PopupMenuItem(value: 'delete', child: Text('Xoá', style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-user',
        onPressed: () async {
          await context.push('/admin/users/new');
          ref.invalidate(adminUsersProvider);
          ref.invalidate(adminStatsProvider);
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Thêm người dùng'),
      ),
    );
  }
}
