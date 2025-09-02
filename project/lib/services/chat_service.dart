// lib/services/chat_service.dart
import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../e2ee/e2ee_key_manager.dart';

final supa = Supabase.instance.client;
final _uuid = const Uuid();
final _keys = E2EEKeyManager();

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? ctB64;
  final String? nonceB64;
  final String? macB64;
  final DateTime createdAt;

  ChatMessage.fromJson(Map<String, dynamic> m)
      : id = m['id'],
        conversationId = m['conversation_id'],
        senderId = m['sender_id'],
        ctB64 = m['body_ciphertext_base64'],
        nonceB64 = m['body_nonce_base64'],
        macB64 = m['body_mac_base64'],
        createdAt = DateTime.parse(m['created_at']);
}

class ChatService {
  // ---- NEW: CEK cache (conversationId -> key bytes)
  final Map<String, List<int>> _cekCache = {};

  Future<void> ensureMyLongTermKey() async {
    await _keys.loadKeyPairFromStorage();
  }

  Future<String> createOrGetDm(String otherUserId) async {
    final me = supa.auth.currentUser!.id;
    final res = await supa
        .rpc('create_1to1_conversation', params: {'a': me, 'b': otherUserId});
    final convId = res as String;
    await bootstrapCekIfMissing(convId);
    return convId;
  }

  Future<void> bootstrapCekIfMissing(String conversationId) async {
    final me = supa.auth.currentUser!.id;

    final parts = await supa
        .from('participants')
        .select(
            'user_id, cek_wrapped_ciphertext_base64, cek_wrapped_nonce_base64, cek_wrapped_ephemeral_pub_base64')
        .eq('conversation_id', conversationId);

    final list = (parts as List).cast<Map<String, dynamic>>();
    final myRow =
        list.firstWhere((p) => p['user_id'] == me, orElse: () => {});

    final hasMyWrapped = (myRow['cek_wrapped_ciphertext_base64'] != null);
    if (hasMyWrapped) return;

    final cek = List<int>.generate(32, (_) => Random.secure().nextInt(256));

    for (final p in list) {
      final uid = p['user_id'] as String;
      final pub = await _keys.getUserPublicKey(uid);
      final wrapped = await _keys.wrapCekForUser(
        cekBytes32: cek,
        recipientPub: pub,
      );

      await supa.rpc('set_conversation_cek', params: {
        '_conversation_id': conversationId,
        '_target_user_id': uid,
        '_cek_version': 1,
        '_wrapped_ct_base64': wrapped['wrapped_ct_b64'],
        '_wrapped_nonce_base64': wrapped['wrapped_nonce_b64'],
        '_eph_pub_base64': wrapped['eph_pub_b64'],
      });
    }

    // CEK cache'i temizle (yeni CEK olmuş olabilir)
    _cekCache.remove(conversationId);
  }

  Future<List<int>> getMyCek(String conversationId) async {
    // ---- NEW: cache kullan
    final cached = _cekCache[conversationId];
    if (cached != null) return cached;

    final me = supa.auth.currentUser!.id;
    final row = await supa
        .from('participants')
        .select(
            'cek_wrapped_ciphertext_base64, cek_wrapped_nonce_base64, cek_wrapped_ephemeral_pub_base64')
        .match({'conversation_id': conversationId, 'user_id': me})
        .maybeSingle();

    Future<List<int>> unwrapFn(Map<String, dynamic> r) async {
      final k = await _keys.unwrapCekForMe(
        wrappedCtB64: r['cek_wrapped_ciphertext_base64'],
        wrappedNonceB64: r['cek_wrapped_nonce_base64'],
        ephPubB64: r['cek_wrapped_ephemeral_pub_base64'],
      );
      _cekCache[conversationId] = k; // ---- NEW: cache'e koy
      return k;
    }

    if (row == null || row['cek_wrapped_ciphertext_base64'] == null) {
      await bootstrapCekIfMissing(conversationId);
      final row2 = await supa
          .from('participants')
          .select(
              'cek_wrapped_ciphertext_base64, cek_wrapped_nonce_base64, cek_wrapped_ephemeral_pub_base64')
          .match({'conversation_id': conversationId, 'user_id': me})
          .maybeSingle();
      if (row2 == null || row2['cek_wrapped_ciphertext_base64'] == null) {
        throw Exception('CEK not available for this conversation.');
      }
      return unwrapFn(row2);
    }
    return unwrapFn(row);
  }

  Future<List<Map<String, dynamic>>> getConversationsBasic() async {
    final rows = await supa.rpc('get_conversations_basic');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<ChatMessage?> fetchLastMessage(String conversationId) async {
    final rows = await supa
        .from('messages')
        .select()
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
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<List<ChatMessage>> fetchBefore(String conversationId, DateTime before,
      {int limit = 30}) async {
    final rows = await supa
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .lt('created_at', before.toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    final list =
        (rows as List).map((e) => ChatMessage.fromJson(e)).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<void> sendTextEncrypted({
    required String conversationId,
    required String text,
  }) async {
    final cek = await getMyCek(conversationId);
    final enc = await _keys.encryptMessage(
      cekBytes32: cek,
      plaintext: text,
      conversationId: conversationId,
    );

    await supa.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': supa.auth.currentUser!.id,
      'body_ciphertext_base64': enc['ct_b64'],
      'body_nonce_base64': enc['nonce_b64'],
      'body_mac_base64': enc['mac_b64'],
      'client_msg_id': _uuid.v4(),
    });

    await supa
        .from('conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<String> decryptMessageForUi(ChatMessage m) async {
    if (m.ctB64 == null || m.nonceB64 == null || m.macB64 == null) return '';
    final cek = await getMyCek(m.conversationId);
    return _keys.decryptMessage(
      cekBytes32: cek,
      ctB64: m.ctB64!,
      nonceB64: m.nonceB64!,
      macB64: m.macB64!,
      conversationId: m.conversationId,
    );
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

  // Presence (typing) — sürümden bağımsız
RealtimeChannel joinPresence(
  String conversationId,
  void Function(Set<String>) onSync,
) {
  final ch = supa.channel('presence:$conversationId');

  // metas/payload yapısını dinamik olarak tüket
  void _consumeMeta(dynamic meta, Set<String> out) {
    String? uid;
    bool isTyping = false;

    if (meta is Map) {
      uid = meta['userId'] as String?;
      isTyping = meta['typing'] == true;
    } else {
      // dinamik alanlar (bazı SDK'larda PresenceMeta gibi sınıflar)
      try { uid = (meta as dynamic).userId as String?; } catch (_) {}
      try { isTyping = (meta as dynamic).typing == true; } catch (_) {}
    }
    if (isTyping && uid != null) out.add(uid);
  }

  ch
    ..onPresenceSync((_) {
      final state = ch.presenceState(); // Map veya List olabilir
      final typing = <String>{};

      if (state is Map) {
        // Map<String, List<dynamic>>
        for (final metas in (state as Map).values) {
          if (metas is List) {
            for (final meta in metas) {
              _consumeMeta(meta, typing);
            }
          }
        }
      } else if (state is List) {
        // List<SinglePresenceState> veya benzeri
        for (final item in (state as List)) {
          final dynamic d = item;
          List<dynamic>? metas;
          // bazı sürümlerde 'metas', bazılarında 'payload' oluyor
          try { metas = (d.metas as List?); } catch (_) {}
          try { metas ??= (d.payload as List?); } catch (_) {}
          if (metas != null) {
            for (final meta in metas) {
              _consumeMeta(meta, typing);
            }
          }
        }
      }

      onSync(typing);
    })
    ..subscribe();

  ch.track({
    'userId': supa.auth.currentUser!.id,
    'typing': false,
  });

  return ch;
}


  Future<void> trackTyping(RealtimeChannel presence, bool isTyping) async {
    await presence.track({
      'userId': supa.auth.currentUser!.id,
      'typing': isTyping,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markRead(String conversationId) async {
    await supa.rpc('mark_read', params: {'_conversation_id': conversationId});
  }

Future<Map<String, UserDisplay>> getDisplayMap(List<String> userIds) async {
  final ids = userIds.where((e) => e.isNotEmpty).toSet().toList();
  if (ids.isEmpty) return {};

  try {
    final rows = await supa.rpc('get_user_display_bulk', params: {'_ids': ids});
    final list = (rows as List)
        .cast<Map<String, dynamic>>()
        .map((e) => UserDisplay.fromJson(e));
    return {for (final u in list) u.userId: u};
  } catch (e) {
    // Fallback: show short uuid (keeps UI working if RPC not deployed yet)
    return {
      for (final id in ids)
        id: UserDisplay(userId: id, displayName: 'User ${id.substring(0, 6)}')
    };
  }
}
}

// --- Display name model + bulk fetch ---
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





