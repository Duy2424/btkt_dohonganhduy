// Ticket hỗ trợ của phụ huynh: danh sách ticket của mình + nút gửi yêu cầu mới.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/tickets_api.dart';
import '../widgets/ticket_list_view.dart';

class TicketListScreen extends ConsumerWidget {
  const TicketListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hỗ trợ')),
      body: const TicketListView(emptyMessage: 'Bạn chưa gửi yêu cầu hỗ trợ nào'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/parent/tickets/new');
          ref.invalidate(ticketsProvider);
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Gửi yêu cầu'),
      ),
    );
  }
}
