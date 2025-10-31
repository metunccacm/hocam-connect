// lib/view/chat_list_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../utils/network_error_handler.dart';
import 'chat_view.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key});
  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final _svc = ChatService();
  final _supa = Supabase.instance.client;

  // data
  List<String> _convIds = [];
  final Map<String, String> _title = {};
  final Map<String, String?> _avatar = {};
  final Map<String, String> _snippet = {};
  final Map<String, DateTime?> _lastTime = {};
  final Map<String, int> _unread = {};

  // members map (conv -> userIds)
  final Map<String, List<String>> _members = {};

  // block status per conversation
  final Map<String, bool> _isDm = {};
  final Map<String, bool> _iBlocked = {}; // I blocked them
  final Map<String, bool> _blockedMe = {}; // they blocked me

  // ui
  bool _loading = true;
  bool _hasNetworkError = false;
  String? _errorMessage;
  String _query = '';
  final _search = TextEditingController();

  // realtime
  RealtimeChannel? _msgCh;
  RealtimeChannel? _partCh;
  RealtimeChannel? _blockChMine; // changes where I am blocker
  RealtimeChannel? _blockChOther; // changes where I am blocked


  final TextEditingController _chatReportCtrl = TextEditingController();
  final List<String> _reportReasons = const [
    'Harassment / Abuse',
    'Scam / Fraud',
    'Spam',
    'Hate / Threats',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _msgCh?.unsubscribe();
    _partCh?.unsubscribe();
    _blockChMine?.unsubscribe();
    _blockChOther?.unsubscribe();
    _search.dispose();
    _chatReportCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _load();
    await _loadUnread();
    _subscribeRealtime();
  }

  // ----------------------- LOADERS -----------------------

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasNetworkError = false;
      _errorMessage = null;
    });
    
    try {
      // tüm konuşmalar
      List<String> convs = [];
      try {
        final rows = await NetworkErrorHandler.handleNetworkCall(
          () => _svc.getConversationsBasic(),
          context: 'Failed to load conversations',
        );
        convs = rows
            .map((e) => (e['id'] ?? e['conversation_id']) as String)
            .toList();
      } catch (_) {
        final me = _supa.auth.currentUser!.id;
        final rows = await NetworkErrorHandler.handleNetworkCall(
          () => _supa
              .from('participants')
              .select('conversation_id')
              .eq('user_id', me),
          context: 'Failed to load conversations',
        );
        convs = (rows as List)
            .map(
                (e) => (e as Map<String, dynamic>)['conversation_id'] as String)
            .toList();
      }

      convs = convs.toSet().where((e) => e.isNotEmpty).toList();
      await Future.wait(convs.map(_ensureMeta));

      _resort(convs);

      if (!mounted) return;
      setState(() {
        _convIds = convs;
        _loading = false;
        _hasNetworkError = false;
        _errorMessage = null;
      });
    } on HC50Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasNetworkError = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasNetworkError = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load chats: $e')),
      );
    }
  }

  // Get other user id
  Future<String?> _getOtherUserIdFor(String conversationId) async {
    final me = _supa.auth.currentUser!.id;
    var mem = _members[conversationId];
    if (mem == null) {
      await _ensureMeta(conversationId); // fills _members
      mem = _members[conversationId];
    }
    if (mem == null) return null;
    final others = mem.where((u) => u != me).toList();
    return (others.length == 1) ? others.first : null; // only for DMs
  }

Future<void> _reportAfterBlock(String conversationId) async {
  final other = await _getOtherUserIdFor(conversationId);
  if (other == null) return; // group or not resolvable -> silently skip

  String selected = _reportReasons.first;
  _chatReportCtrl.clear();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Report user'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: selected,
            items: _reportReasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => selected = v ?? selected,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _chatReportCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              hintText: 'Add any context (optional)…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
      ],
    ),
  );

  if (ok != true) return;

  final me = _supa.auth.currentUser?.id;
  if (me == null) return;

  try {
    await _supa.from('chat_abuse_reports').insert({
      'conversation_id': conversationId,
      'reporter_id': me,
      'reported_user_id': other,
      'reason': selected,
      'details': _chatReportCtrl.text.trim().isEmpty ? null : _chatReportCtrl.text.trim(),
      'message_id': null,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
  } on PostgrestException catch (e) {
    if (e.code == '23505') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already reported this conversation.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit: ${e.message}')));
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
  }
}



  Future<void> _loadUnread() async {
    try {
      final rows = await _supa.rpc('get_unread_counts');
      final list = (rows as List).cast<Map<String, dynamic>>();
      _unread.clear();
      for (final r in list) {
        _unread[r['conversation_id'] as String] = (r['unread'] as int?) ?? 0;
      }
      for (final id in _convIds) {
        _unread[id] = _unread[id] ?? 0;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // snippet üretirken decrypt fail olursa: 1 kere E2EE repair deneyelim
  Future<String> _safeDecryptSnippet(ChatMessage last) async {
    try {
      await _svc.ensureMyLongTermKey(); // cihaz anahtarı garanti
      await _svc.bootstrapCekIfMissing(last.conversationId);
      return await _svc.decryptMessageForUi(last);
    } catch (_) {
      // tek seferlik repair (varsa rpc)
      try {
        await _supa
            .rpc('reset_conv_cek', params: {'_cid': last.conversationId});
        await _svc.bootstrapCekIfMissing(last.conversationId);
        return await _svc.decryptMessageForUi(last);
      } catch (_) {
        // yine de olmadıysa güvenli yer tutucu
        return '(encrypted)';
      }
    }
  }

  Future<void> _ensureMeta(String conversationId) async {
    // title & avatar & members
    if (!_title.containsKey(conversationId)) {
      final me = _supa.auth.currentUser!.id;
      final parts = await _supa
          .from('participants')
          .select('user_id')
          .eq('conversation_id', conversationId);

      final userIds = (parts as List)
          .map((e) => (e as Map<String, dynamic>)['user_id'] as String)
          .toList();

      _members[conversationId] = userIds;
      final others = userIds.where((u) => u != me).toList();

      if (others.length == 1) {
        final map = await _svc.getDisplayMap([others.first]);
        final d = map[others.first];
        _title[conversationId] =
            d?.displayName ?? 'User ${others.first.substring(0, 6)}';
        _avatar[conversationId] = d?.avatarUrl;
      } else if (others.length > 1) {
        _title[conversationId] = 'Group (${others.length + 1})';
        _avatar[conversationId] = null;
      } else {
        _title[conversationId] = 'Saved messages';
        _avatar[conversationId] = null;
      }
    }

    // last message -> snippet
    if (!_snippet.containsKey(conversationId)) {
      final last = await _svc.fetchLastMessage(conversationId);
      if (last == null) {
        _snippet[conversationId] = '';
        _lastTime[conversationId] = null;
      } else {
        final txt = await _safeDecryptSnippet(last);
        _snippet[conversationId] = txt;
        _lastTime[conversationId] = last.createdAt.toLocal();
      }
    }

    // block status (once)
    if (!_isDm.containsKey(conversationId)) {
      try {
        final st = await _svc.getBlockStatus(conversationId);
        _isDm[conversationId] = st.isDm;
        _iBlocked[conversationId] = st.iBlocked;
        _blockedMe[conversationId] = st.blockedMe;
      } catch (_) {
        _isDm[conversationId] = false;
        _iBlocked[conversationId] = false;
        _blockedMe[conversationId] = false;
      }
    }
  }

  void _resort(List<String> ids) {
    ids.sort((a, b) {
      final ta = _lastTime[a]?.millisecondsSinceEpoch ?? 0;
      final tb = _lastTime[b]?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
  }

  // ----------------------- REALTIME -----------------------

  void _subscribeRealtime() {
    final me = _supa.auth.currentUser!.id;

    // Mesaj insertleri -> snippet + unread
    _msgCh = _supa.channel('chatlist:messages')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final m = ChatMessage.fromJson(payload.newRecord);
          if (!_convIds.contains(m.conversationId)) {
            await _onNewConversationDetected(m.conversationId);
          }
          _lastTime[m.conversationId] = m.createdAt.toLocal();
          
          String messageText = '(encrypted)';
          try {
            messageText = await _safeDecryptSnippet(m);
            _snippet[m.conversationId] = messageText;
          } catch (_) {
            _snippet[m.conversationId] = messageText;
          }
          
          // Update unread count for messages from others
          // In-app notifications are now handled by GlobalChatNotificationService
          if (m.senderId != me) {
            _unread[m.conversationId] = (_unread[m.conversationId] ?? 0) + 1;
          }
          
          _resort(_convIds);
          if (mounted) setState(() {});
        },
      )
      ..subscribe();

    // participants: katıl/çıkar & unread reset
    _partCh = _supa.channel('chatlist:participants')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'participants',
        callback: (payload) async {
          final r = payload.newRecord;
          if (r['user_id'] == me) {
            final cid = r['conversation_id'] as String;
            await _onNewConversationDetected(cid);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'participants',
        callback: (payload) async {
          final r = payload.newRecord;
          if (r['user_id'] == me) {
            final cid = r['conversation_id'] as String;
            // server unread sıfırlanınca hemen UI’da sıfırla
            _unread[cid] = 0;
            if (mounted) setState(() {});
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'participants',
        callback: (payload) async {
          final r = payload.oldRecord;
          if (r['user_id'] == me) {
            final cid = r['conversation_id'] as String;
            _removeLocal(cid);
          }
        },
      )
      ..subscribe();

    // BLOCK realtime — ben bloklarsam (blocker_id == me)
    _blockChMine = _supa.channel('chatlist:user_blocks:mine')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'user_blocks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'blocker_id',
          value: me,
        ),
        callback: (payload) async {
          final other = payload.newRecord['blocked_id'] as String?;
          if (other == null) return;
          final cid = _findDmWith(other);
          if (cid != null) {
            _isDm[cid] = true;
            _iBlocked[cid] = true;
            if (mounted) setState(() {});
          }
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
        callback: (payload) async {
          final other = payload.oldRecord['blocked_id'] as String?;
          if (other == null) return;
          final cid = _findDmWith(other);
          if (cid != null) {
            _iBlocked[cid] = false;
            if (mounted) setState(() {});
          }
        },
      )
      ..subscribe();

    // BLOCK realtime — karşı taraf beni bloklarsa (blocked_id == me)
    _blockChOther = _supa.channel('chatlist:user_blocks:other')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'user_blocks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'blocked_id',
          value: me,
        ),
        callback: (payload) async {
          final blocker = payload.newRecord['blocker_id'] as String?;
          if (blocker == null) return;
          final cid = _findDmWith(blocker);
          if (cid != null) {
            _isDm[cid] = true;
            _blockedMe[cid] = true;
            if (mounted) setState(() {});
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'user_blocks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'blocked_id',
          value: me,
        ),
        callback: (payload) async {
          final blocker = payload.oldRecord['blocker_id'] as String?;
          if (blocker == null) return;
          final cid = _findDmWith(blocker);
          if (cid != null) {
            _blockedMe[cid] = false;
            if (mounted) setState(() {});
          }
        },
      )
      ..subscribe();
  }

  String? _findDmWith(String other) {
    final me = _supa.auth.currentUser!.id;
    for (final entry in _members.entries) {
      final ids = entry.value;
      if (ids.length == 2 && ids.contains(me) && ids.contains(other)) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _onNewConversationDetected(String cid) async {
    if (_convIds.contains(cid)) return;
    await _ensureMeta(cid);
    _convIds.add(cid);
    _unread[cid] = _unread[cid] ?? 0;
    _resort(_convIds);
    if (mounted) setState(() {});
  }

  void _removeLocal(String cid) {
    _convIds.remove(cid);
    _title.remove(cid);
    _avatar.remove(cid);
    _snippet.remove(cid);
    _lastTime.remove(cid);
    _unread.remove(cid);
    _isDm.remove(cid);
    _iBlocked.remove(cid);
    _blockedMe.remove(cid);
    if (mounted) setState(() {});
  }

  // ----------------------- ACTIONS -----------------------

  Future<void> _openChat(String id) async {
    final title = _title[id] ?? 'Chat';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatView(conversationId: id, title: title),
      ),
    );

    // DÖNÜNCE: unread sıfırla + snippet’ı tazele
    try {
      await _supa.rpc('mark_read', params: {'_conversation_id': id});
    } catch (_) {}
    _unread[id] = 0;

    // son mesajı tekrar çek (okundu sonrası da aynı kalır ama emin olalım)
    try {
      final last = await _svc.fetchLastMessage(id);
      if (last != null) {
        _snippet[id] = await _safeDecryptSnippet(last);
        _lastTime[id] = last.createdAt.toLocal();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _deleteForMe(String id) async {
    try {
      final me = _supa.auth.currentUser!.id;
      await _supa.from('participants').delete().match({
        'conversation_id': id,
        'user_id': me,
      });
      _removeLocal(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _deleteEverywhere(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
            'This will permanently delete all messages for this conversation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _supa
          .rpc('hard_delete_conversation', params: {'_conversation_id': id});
      _removeLocal(id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Conversation deleted')));
    } catch (e) {
      final fallback = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Not allowed to delete for everyone'),
          content: const Text('Remove it only for you?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete for me')),
          ],
        ),
      );
      if (fallback == true) {
        await _deleteForMe(id);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _blockInDm(String id) async {
    try {
      await _supa.rpc('block_user_in_dm', params: {'_conversation_id': id});
      _iBlocked[id] = true; // immediate reflect
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User blocked')));
          await _reportAfterBlock(id);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Block failed: $e')));
    }
  }

  Future<void> _unblockInDm(String id) async {
    try {
      await _supa.rpc('unblock_user_in_dm', params: {'_conversation_id': id});
      _iBlocked[id] = false; // immediate reflect
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User unblocked')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unblock failed: $e')));
    }
  }

  // ----------------------- UI -----------------------

  @override
  Widget build(BuildContext context) {
    final filtered = _convIds.where((id) {
      if (_query.isEmpty) return true;
      final t = (_title[id] ?? '').toLowerCase();
      final s = (_snippet[id] ?? '').toLowerCase();
      final q = _query.toLowerCase();
      return t.contains(q) || s.contains(q);
    }).toList();

    return Scaffold(
      appBar: HCAppBar(
        centerTitle: true,
        title: 'Chats',
        titleStyle: TextStyle(fontSize: 18),
        actions: [
          IconButton(
            icon: const Icon(Icons.question_mark_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Information'),
                  content: const Text(
                      'You can swipe a DM left to reveal Block / Delete.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close')),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasNetworkError
              ? NetworkErrorView(
                  message: _errorMessage ?? 'Unable to load chats',
                  onRetry: _load,
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildBody(filtered),
    );
  }

  Widget _buildBody(List<String> ids) {
    if (ids.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _load();
          await _loadUnread();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 80),
            const Center(child: Text('No conversations yet')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await _loadUnread();
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: ids.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildSearchBar(),
            );
          }
          final id = ids[i - 1];
          final title = _title[id] ?? 'Chat';
          final sub = _snippet[id] ?? '';
          final t = _lastTime[id];
          final avatar = _avatar[id];
          final unread = _unread[id] ?? 0;

          final isDm = _isDm[id] ?? false;
          final iBlocked = _iBlocked[id] ?? false;
          final blockedMe = _blockedMe[id] ?? false;

          return Slidable(
            key: ValueKey('conv-$id'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: isDm ? 0.45 : 0.25, // DM ise daha geniş alan
              children: [
                if (isDm)
                  SlidableAction(
                    onPressed: (_) =>
                        iBlocked ? _unblockInDm(id) : _blockInDm(id),
                    backgroundColor: iBlocked
                        ? const Color(0xFFE8F5E9) // unblock rengi
                        : const Color(0xFFFFEEF0), // block rengi
                    foregroundColor:
                        iBlocked ? const Color(0xFF2E7D32) : Colors.red,
                    icon: iBlocked ? Icons.lock_open : Icons.block,
                    label: iBlocked ? 'Unblock' : 'Block',
                    borderRadius: BorderRadius.circular(12),
                  ),
                SlidableAction(
                  onPressed: (_) => _deleteEverywhere(id),
                  backgroundColor: const Color(0xFFFFF4E5),
                  foregroundColor: const Color(0xFFD35400),
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: avatar != null && avatar.isNotEmpty
                  ? CircleAvatar(backgroundImage: NetworkImage(avatar))
                  : CircleAvatar(
                      child: Text(
                          title.isNotEmpty ? title[0].toUpperCase() : '?')),
              title: Row(
                children: [
                  Expanded(
                      child: Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (isDm && (iBlocked || blockedMe))
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.block,
                          size: 16, color: Colors.red.withOpacity(0.8)),
                    ),
                ],
              ),
              subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (t != null)
                    Text(_fmtTime(t),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 6),
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              onTap: () => _openChat(id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.black38),
          hintText: 'Search',
          border: InputBorder.none,
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final d = t.isUtc ? t.toLocal() : t;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);

    if (that == today) {
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
