import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'chat_view.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final _svc = ChatService();
  final _supa = Supabase.instance.client;

  List<String> _convIds = [];
  bool _loading = true;

  final Map<String, String> _title = {};
  final Map<String, String?> _avatar = {};
  final Map<String, String> _snippet = {};
  final Map<String, DateTime?> _lastTime = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      List<String> convs = [];
      try {
        final rows = await _svc.getConversationsBasic();
        convs = rows.map((e) => (e['id'] ?? e['conversation_id']) as String).toList();
      } catch (_) {
        final me = _supa.auth.currentUser!.id;
        final rows = await _supa
            .from('participants')
            .select('conversation_id')
            .eq('user_id', me);
        convs = (rows as List)
            .map((e) => (e as Map<String, dynamic>)['conversation_id'] as String)
            .toList();
      }

      convs = convs.toSet().where((e) => e.isNotEmpty).toList();

      // Prepare titles/snippets
      await Future.wait(convs.map(_ensureMeta));

      convs.sort((a, b) {
        final ta = _lastTime[a]?.millisecondsSinceEpoch ?? 0;
        final tb = _lastTime[b]?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      setState(() {
        _convIds = convs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load chats: $e')),
      );
    }
  }

  Future<void> _ensureMeta(String conversationId) async {
    if (!_title.containsKey(conversationId)) {
      final me = _supa.auth.currentUser!.id;
      final parts = await _supa
          .from('participants')
          .select('user_id')
          .eq('conversation_id', conversationId);

      final userIds = (parts as List)
          .map((e) => (e as Map<String, dynamic>)['user_id'] as String)
          .toList();

      final others = userIds.where((u) => u != me).toList();

      if (others.length == 1) {
        // 1-1: resolve name
        final map = await _svc.getDisplayMap([others.first]);
        final d = map[others.first];
        _title[conversationId] = d?.displayName ?? 'User ${others.first.substring(0,6)}';
        _avatar[conversationId] = d?.avatarUrl;
      } else if (others.length > 1) {
        _title[conversationId] = 'Group (${others.length + 1})';
        _avatar[conversationId] = null;
      } else {
        _title[conversationId] = 'Saved messages'; // self-DM
        _avatar[conversationId] = null;
      }
    }

    if (!_snippet.containsKey(conversationId)) {
      final last = await _svc.fetchLastMessage(conversationId);
      if (last == null) {
        _snippet[conversationId] = '';
        _lastTime[conversationId] = null;
      } else {
        try {
          final text = await _svc.decryptMessageForUi(last);
          _snippet[conversationId] = text;
          _lastTime[conversationId] = last.createdAt;
        } catch (_) {
          _snippet[conversationId] = '(unable to decrypt)';
          _lastTime[conversationId] = last.createdAt;
        }
      }
    }
  }

  Future<void> _openChat(String id) async {
    final title = _title[id] ?? 'Chat';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatView(conversationId: id, title: title),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _convIds.isEmpty
              ? const Center(child: Text('No conversations yet'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _convIds.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final id = _convIds[i];
                      final title = _title[id] ?? 'Chat';
                      final sub = _snippet[id] ?? '';
                      final t = _lastTime[id];
                      final avatar = _avatar[id];

                      return ListTile(
                        leading: avatar != null && avatar.isNotEmpty
                            ? CircleAvatar(backgroundImage: NetworkImage(avatar))
                            : CircleAvatar(child: Text(title.isNotEmpty ? title[0].toUpperCase() : '?')),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: t == null
                            ? null
                            : Text(
                                _fmtTime(t),
                                style: const TextStyle(color: Colors.black54, fontSize: 12),
                              ),
                        onTap: () => _openChat(id),
                      );
                    },
                  ),
                ),
    );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that  = DateTime(t.year, t.month, t.day);
    if (that == today) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
