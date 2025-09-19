import 'dart:async';
import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';

class ChatView extends StatefulWidget {
  final String conversationId;
  final String title;
  const ChatView({super.key, required this.conversationId, required this.title});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _svc = ChatService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  final Map<String, String> _plain = {};
  final List<String> _queue = [];
  bool _decryptRunning = false;

  RealtimeChannel? _msgChannel;
  RealtimeChannel? _presence;
  RealtimeChannel? _blockCh;
  Set<String> _typing = {};
  Timer? _typingDebounce;
  bool _loadingOlder = false;

  // NEW: block flags
  bool _isDm = false;
  bool _iBlocked = false;
  bool _blockedMe = false;

  // NEW: other display name for banner
  String? _otherDisplayName;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _svc.bootstrapCekIfMissing(widget.conversationId);

    // header info
    unawaited(_loadHeaderMeta());
    unawaited(_loadBlockStatus());

    final initial = await _svc.fetchInitial(widget.conversationId, limit: 30);
    setState(() => _messages = initial);
    for (final m in initial) _enqueueDecrypt(m);

    unawaited(_svc.markRead(widget.conversationId));

    _msgChannel = _svc.subscribeMessages(widget.conversationId, (m) async {
      setState(() => _messages = [..._messages, m]);
      _enqueueDecrypt(m);
      _scrollToBottom();
      _svc.markRead(widget.conversationId);
    });

    _presence = _svc.joinPresence(widget.conversationId, (set) {
      final myId = Supabase.instance.client.auth.currentUser!.id;
      set.remove(myId);
      setState(() => _typing = set);
    });

    _blockCh = await _svc.subscribeDmBlockStatus(widget.conversationId, () async {
      // refresh flags immediately when block/unblock happens
      await _loadBlockStatus();
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _loadHeaderMeta() async {
    try {
      final supa = Supabase.instance.client;
      final me = supa.auth.currentUser!.id;
      final rows = await supa
          .from('participants')
          .select('user_id')
          .eq('conversation_id', widget.conversationId);
      final ids = (rows as List).map((e) => (e as Map<String, dynamic>)['user_id'] as String).toList();
      final others = ids.where((u) => u != me).toList();
      if (others.length == 1) {
        final m = await _svc.getDisplayMap([others.first]);
        _otherDisplayName = m[others.first]?.displayName;
      } else if (others.isEmpty) {
        _otherDisplayName = 'Saved messages';
      } else {
        _otherDisplayName = 'Group chat';
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // NEW
  Future<void> _loadBlockStatus() async {
    try {
      final st = await _svc.getBlockStatus(widget.conversationId);
      setState(() {
        _isDm = st.isDm;
        _iBlocked = st.iBlocked;
        _blockedMe = st.blockedMe;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _presence?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    _typingDebounce?.cancel();
    _blockCh?.unsubscribe();
    super.dispose();
  }

  void _enqueueDecrypt(ChatMessage m) {
    if (_plain.containsKey(m.id)) return;
    if (_queue.contains(m.id)) return;
    _queue.add(m.id);
    if (!_decryptRunning) _runDecryptLoop();
  }

  Future<void> _runDecryptLoop() async {
    _decryptRunning = true;
    while (_queue.isNotEmpty && mounted) {
      final id = _queue.removeAt(0);
      final m = _messages.firstWhere(
        (x) => x.id == id,
        orElse: () => _messages.isNotEmpty ? _messages.last : (throw StateError('message gone')),
      );
      try {
        final t = await _svc.decryptMessageForUi(m);
        _plain[id] = t;
      } catch (_) {
        _plain[id] = '(decrypt failed)';
      }
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 1));
    }
    _decryptRunning = false;
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadOlder() async { /* unchanged */ }

  Future<void> _send() async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;

  // client-side guard (instant UX)
  if (_isDm && (_iBlocked || _blockedMe)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You cannot send messages in this conversation.')),
    );
    return;
  }

  _controller.clear();

  try {
    await _svc.sendTextEncrypted(
      conversationId: widget.conversationId,
      text: text,
    );
  } catch (e) {
    // server-side RLS still blocks even if UI is stale for a moment
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message not sent: blocked. ($e)')),
    );
    return;
  }

  if (_presence != null) {
    unawaited(_svc.trackTyping(_presence!, false));
  }
  _scrollToBottom();
}

  void _onTypingChanged(String _) { /* unchanged */ }
  bool _isMine(ChatMessage m) => m.senderId == Supabase.instance.client.auth.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF007AFF);
    final composerDisabled = _isDm && (_iBlocked || _blockedMe);

    return Scaffold(
      appBar: HCAppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: themeBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_otherDisplayName != null && _otherDisplayName!.isNotEmpty) const SizedBox(width: 8),
                const Icon(Icons.lock, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                const Text('End-to-End encrypted', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
        actions: const [Padding(padding: EdgeInsets.only(right: 12.0), child: CircleAvatar(radius: 16))],
      ),

      body: Column(
        children: [
          // NEW: banner
          if (composerDisabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFFF4E5),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 16, color: Color(0xFFD35400)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _iBlocked
                          ? 'You blocked ${_otherDisplayName ?? "this user"}. Unblock to send messages.'
                          : 'You can’t message this user.',
                      style: const TextStyle(color: Color(0xFF8C4A00)),
                    ),
                  ),
                  if (_iBlocked)
                    TextButton(
                      onPressed: () async {
                        try {
                          await _svc.unblockInDm(widget.conversationId);
                          await _loadBlockStatus();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unblock failed: $e')));
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                ],
              ),
            ),

          // ... your ListView of messages (unchanged except for decrypt cache)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) { if (n.metrics.pixels <= 24) _loadOlder(); return false; },
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final mine = _isMine(m);
                  final text = _plain[m.id];
                  if (text == null) _enqueueDecrypt(m);
                  return Container(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: mine ? themeBlue : const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(mine ? 18 : 6),
                            bottomRight: Radius.circular(mine ? 6 : 18),
                          ),
                        ),
                        child: Text(
                          text ?? '…',
                          style: TextStyle(color: mine ? Colors.white : Colors.black87, fontSize: 16),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          if (_typing.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('typing…', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.add, color: themeBlue), onPressed: composerDisabled ? null : () {}),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: composerDisabled ? null : _onTypingChanged,
                      enabled: !composerDisabled,
                      decoration: InputDecoration(
                        hintText: composerDisabled ? 'Messaging disabled' : 'Type a message…',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: composerDisabled ? null : _send,
                    child: Opacity(
                      opacity: composerDisabled ? 0.5 : 1,
                      child: Container(
                        width: 38, height: 38,
                        decoration: const BoxDecoration(color: themeBlue, shape: BoxShape.circle),
                        child: const Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
