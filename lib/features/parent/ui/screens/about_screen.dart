// Màn "Giới thiệu": tên project, sinh viên thực hiện, URL Web API, tên database đang dùng (đọc từ /health)
// Dùng khi thuyết trình để chứng minh tên cá nhân theo yêu cầu giảng viên.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/env.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/data/auth_api.dart';

final _healthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(authApiProvider).health());

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(_healthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Giới thiệu')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_healthProvider.future),
        child: ListView(
          padding: AppSpacing.page,
          children: [
            const AppLogo(size: 80),
            AppSpacing.gapLg,
            Card(
              child: Column(children: [
                _row('Project', Env.projectName),
                _row('Sinh viên thực hiện', Env.studentName),
                _row('Phiên bản app', Env.appVersion),
                _row('URL Web API', Env.apiBaseUrl),
                health.when(
                  data: (h) => Column(children: [
                    _row('Database đang dùng', '${h['database']}'),
                    _row('Web API', '${h['webapi'] ?? ''} (${h['status']}, DB ${h['db']})'),
                    _row('Server chạy được', '${((h['uptime'] as num?) ?? 0) ~/ 60} phút'),
                  ]),
                  loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                  error: (e, _) => _row('Database đang dùng', 'Không kết nối được server'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => ListTile(title: Text(label), subtitle: SelectableText(value), dense: true);
}
