// Tab "Tổng quan" của phụ huynh: mỗi con một thẻ (trực tuyến, pin, đang ở đâu, cảnh báo mới nhất). Nút thêm con.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/state_views.dart';
import '../../../children/data/models/child_profile.dart';
import '../../../children/state/children_providers.dart';
import '../../../children/ui/widgets/child_card.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AsyncListView<ChildProfile>(
        value: ref.watch(childrenProvider),
        onRefresh: () => ref.read(childrenProvider.notifier).refresh(),
        emptyMessage: 'Chưa có hồ sơ con nào.\nBấm "Thêm con" để bắt đầu.',
        emptyIcon: Icons.child_care,
        itemBuilder: (context, child) => ChildCard(
          child: child,
          onTap: () => context.push('/parent/children/${child.id}'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-child',
        onPressed: () => context.push('/parent/children/new'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm con'),
      ),
    );
  }
}
