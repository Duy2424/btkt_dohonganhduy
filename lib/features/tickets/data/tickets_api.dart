// Model và API ticket hỗ trợ, dùng chung cho phụ huynh, nhân viên, admin (server tự phân quyền).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../children/data/models/child_profile.dart';

final ticketsApiProvider = Provider<TicketsApi>((ref) => TicketsApi(ref.watch(apiClientProvider)));

class TicketMessage {
  const TicketMessage(this.senderId, this.senderRole, this.senderName, this.content, this.createdAt);
  final String senderId;
  final String senderRole;
  final String senderName;
  final String content;
  final DateTime? createdAt;
}

class Ticket {
  const Ticket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.parentName,
    this.assignedStaffId,
    this.assignedStaffName,
    this.lastMessage = '',
    this.messageCount = 0,
    this.updatedAt,
    this.messages = const [],
  });

  final String id;
  final String subject;
  final String category;
  final String status;
  final String parentName;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String lastMessage;
  final int messageCount;
  final DateTime? updatedAt;
  final List<TicketMessage> messages;

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: j['id'] as String,
        subject: j['subject'] as String,
        category: j['category'] as String,
        status: j['status'] as String,
        parentName: (j['parentName'] ?? '') as String,
        assignedStaffId: j['assignedStaffId'] as String?,
        assignedStaffName: j['assignedStaffName'] as String?,
        lastMessage: (j['lastMessage'] ?? '') as String,
        messageCount: (j['messageCount'] as num?)?.toInt() ?? 0,
        updatedAt: parseDate(j['updatedAt']),
        messages: ((j['messages'] as List?) ?? const [])
            .map((m) => TicketMessage(
                  m['senderId'] as String,
                  m['senderRole'] as String,
                  (m['senderName'] ?? '') as String,
                  m['content'] as String,
                  parseDate(m['createdAt']),
                ))
            .toList(),
      );
}

class TicketPage {
  const TicketPage(this.items, {this.counts = const {}});
  final List<Ticket> items;
  final Map<String, int> counts; // nhân viên: queue / mine / done
}

class TicketsApi {
  TicketsApi(this._api);
  final ApiClient _api;

  Future<TicketPage> list({String? status, String scope = 'all', String search = ''}) async {
    final d = await _api.get('/api/tickets', query: {'status': status, 'scope': scope, 'search': search, 'limit': 100});
    final counts = (d['counts'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? const {};
    return TicketPage(
      (d['items'] as List).map((e) => Ticket.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      counts: counts,
    );
  }

  Future<Ticket> get(String id) async => Ticket.fromJson(Map<String, dynamic>.from(await _api.get('/api/tickets/$id') as Map));

  Future<Ticket> create(String subject, String category, String content) async => Ticket.fromJson(Map<String, dynamic>.from(
      await _api.post('/api/tickets', data: {'subject': subject, 'category': category, 'content': content}) as Map));

  Future<void> claim(String id) => _api.post('/api/tickets/$id/claim');
  Future<void> setStatus(String id, String status) => _api.patch('/api/tickets/$id', data: {'status': status});
  Future<void> sendMessage(String id, String content) => _api.post('/api/tickets/$id/messages', data: {'content': content});
  Future<void> delete(String id) => _api.delete('/api/tickets/$id');
}

/// Danh sách ticket theo (scope, status). Làm mới: ref.invalidate(ticketsProvider).
final ticketsProvider = FutureProvider.family<TicketPage, (String, String?)>(
  (ref, key) => ref.watch(ticketsApiProvider).list(scope: key.$1, status: key.$2),
);

final ticketDetailProvider = FutureProvider.family<Ticket, String>((ref, id) => ref.watch(ticketsApiProvider).get(id));
