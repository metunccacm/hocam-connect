// lib/services/chat_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supa = Supabase.instance.client;
final _uuid = const Uuid();

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        senderId: m['sender_id'] as String,
        body: (m['body'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

class ChatService {
  /// Faz-1: E2EE yok. Bu fonksiyon no-op kalsın ki HomeView vs. çağırırsa kırılmasın.
  Future<void> ensureMyLongTermKey() async {
    return;
  }

  Future<String> createOrGetDm(String otherUserId) async {
    final me = supa.auth.currentUser!.id;
    final res = await supa
        .rpc('create_1to1_conversation', params: {'a': me, 'b': otherUserId});
    return res as String;
  }

  Future<List<Map<String, dynamic>>> getConversationsBasic() async {
    final rows = await supa.rpc('get_conversations_basic');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<ChatMessage?> fetchLastMessage(String conversationId) async {
    final rows = await supa
        .from('messages')
        .select('id, conversation_id, sender_id, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return ChatMessage.fromJson(rows.first);
  }

  Future<List<ChatMessage>> fetchInitial(String conversationId,
      {int limit = 30}) async {
    final rows = await supa
        .from('messages')
        .select('id, conversation_id, sender_id, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<List<ChatMessage>> fetchBefore(String conversationId, DateTime before,
      {int limit = 30}) async {
    final rows = await supa
        .from('messages')
        .select('id, conversation_id, sender_id, body, created_at')
        .eq('conversation_id', conversationId)
        .lt('created_at', before.toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    final list =
        (rows as List).map((e) => ChatMessage.fromJson(e)).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Faz-1: düz metin gönder
  Future<void> sendText({
    required String conversationId,
    required String text,
  }) async {
    await supa.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': supa.auth.currentUser!.id,
      'body': text,
      'client_msg_id': _uuid.v4(),
    });

    await supa
        .from('conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  RealtimeChannel subscribeMessages(
      String conversationId, void Function(ChatMessage) onInsert) {
    final ch = supa.channel('msg-conv-$conversationId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) =>
            onInsert(ChatMessage.fromJson(payload.newRecord)),
      )
      ..subscribe();
    return ch;
  }

  Future<void> markRead(String conversationId) async {
    await supa.rpc('mark_read', params: {'_conversation_id': conversationId});
  }

  // --- Display & Block helpers (aynen bırak) ---
  Future<Map<String, UserDisplay>> getDisplayMap(List<String> userIds) async {
    final ids = userIds.where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};

    try {
      final rows =
          await supa.rpc('get_user_display_bulk', params: {'_ids': ids});
      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map((e) => UserDisplay.fromJson(e));
      return {for (final u in list) u.userId: u};
    } catch (e) {
      return {
        for (final id in ids)
          id: UserDisplay(userId: id, displayName: 'User ${id.substring(0, 6)}')
      };
    }
  }

  Future<BlockStatus> getBlockStatus(String conversationId) async {
    final rows =
        await supa.rpc('get_dm_block_status', params: {'_conversation_id': conversationId});
    final data =
        (rows as List).isNotEmpty ? rows.first as Map<String, dynamic> : {};
    return BlockStatus(
      isDm: (data['is_dm'] as bool?) ?? false,
      iBlocked: (data['i_blocked'] as bool?) ?? false,
      blockedMe: (data['blocked_me'] as bool?) ?? false,
    );
  }

  Future<void> unblockInDm(String conversationId) async {
    await supa.rpc('unblock_user_in_dm',
        params: {'_conversation_id': conversationId});
  }

  Future<List<String>> getParticipantIds(String conversationId) async {
    final rows = await supa
        .from('participants')
        .select('user_id')
        .eq('conversation_id', conversationId);
    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['user_id'] as String)
        .toList();
  }

  Future<RealtimeChannel?> subscribeDmBlockStatus(
    String conversationId,
    FutureOr<void> Function() onChange,
  ) async {
    final ids = await getParticipantIds(conversationId);
    if (ids.length != 2) return null; // not a DM
    final me = supa.auth.currentUser!.id;
    final other = ids.firstWhere((u) => u != me, orElse: () => me);

    final ch = supa.channel('dmblocks:$conversationId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'user_blocks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'blocker_id',
          value: me,
        ),
        callback: (payload) {
          if (payload.newRecord['blocked_id'] == other) onChange();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'user_blocks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'blocker_id',
          value: me,
        ),
        callback: (payload) {
          if (payload.oldRecord['blocked_id'] == other) onChange();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'user_blocks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'blocker_id',
          value: other,
        ),
        callback: (payload) {
          if (payload.newRecord['blocked_id'] == me) onChange();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'user_blocks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'blocker_id',
          value: other,
        ),
        callback: (payload) {
          if (payload.oldRecord['blocked_id'] == me) onChange();
        },
      )
      ..subscribe();

    return ch;
  }
}

class UserDisplay {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  UserDisplay({required this.userId, required this.displayName, this.avatarUrl});
  factory UserDisplay.fromJson(Map<String, dynamic> m) => UserDisplay(
        userId: m['user_id'] as String,
        displayName: (m['display_name'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
      );
}

class BlockStatus {
  final bool isDm;
  final bool iBlocked;
  final bool blockedMe;
  BlockStatus(
      {required this.isDm, required this.iBlocked, required this.blockedMe});
}
