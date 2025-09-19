import 'dart:async';
import 'package:flutter/material.dart';
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

  bool _isDm = false;
  bool _iBlocked = false;
  bool _blockedMe = false;
  String? _otherDisplayName;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    // kapatırken de okundu işaretle (geri dönüşte badge sıfırlasın)
    _svc.markRead(widget.conversationId);
    _msgChannel?.unsubscribe();
    _presence?.unsubscribe();
    _blockCh?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isMine(ChatMessage m) =>
      Supabase.instance.client.auth.currentUser?.id == m.senderId;

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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

  Future<void> _bootstrap() async {
    // E2EE anahtarlar (her launch’ta garanti)
    await _svc.ensureMyLongTermKey();

    // DM/E2EE meta
    unawaited(_loadHeaderMeta());
    unawaited(_loadBlockStatus());

    // CEK dağıt/yenile (eksikse)
    await _svc.bootstrapCekIfMissing(widget.conversationId);

    // İlk mesajlar + decrypt kuyruğu
    final initial = await _svc.fetchInitial(widget.conversationId, limit: 30);
    setState(() => _messages = initial);
    for (final m in initial) {
      _enqueueDecrypt(m);
    }

    // Okundu
    unawaited(_svc.markRead(widget.conversationId));

    // Realtime mesaj
    _msgChannel = _svc.subscribeMessages(widget.conversationId, (m) async {
      setState(() => _messages = [..._messages, m]);
      _enqueueDecrypt(m);
      _scrollToBottom();
      _svc.markRead(widget.conversationId); // canlıyken geleni de okundu
    });

    // Typing presence
    _presence = _svc.joinPresence(widget.conversationId, (set) {
      final myId = Supabase.instance.client.auth.currentUser!.id;
      set.remove(myId);
      setState(() => _typing = set);
    });

    // DM block dinleme
    _blockCh = await _svc.subscribeDmBlockStatus(widget.conversationId, () async {
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
      final ids = (rows as List)
          .map((e) => (e as Map<String, dynamic>)['user_id'] as String)
          .toList();
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_isDm && (_iBlocked || _blockedMe)) {
      _show('You cannot send messages in this conversation.');
      return;
    }

    _controller.clear();

    try {
      await _svc.sendTextEncrypted(
        conversationId: widget.conversationId,
        text: text,
      );
    } catch (e) {
      if (e is PostgrestException) {
        final code = e.code ?? '';
        final message = (e.message ?? '').trim();
        final details = (e.details ?? '').toString().trim();
        final hint = (e.hint ?? '').toString().trim();

        final msgLower = message.toLowerCase();
        final isPerm = code == '42501' ||
            msgLower.contains('permission denied') ||
            msgLower.contains('row-level security');

        final sb = StringBuffer()
          ..writeln('Message not sent:')
          ..writeln(code.isNotEmpty ? 'code=$code' : 'code=<none>')
          ..writeln('message=${message.isEmpty ? "<empty>" : message}');
        if (details.isNotEmpty) sb.writeln('details=$details');
        if (hint.isNotEmpty) sb.writeln('hint=$hint');

        if (isPerm) {
          _show('${sb.toString()}\n⇒ Looks like a policy / permission issue.');
        } else {
          _show(sb.toString());
        }
        return;
      }
      _show('Message not sent: $e');
      return;
    }

    if (_presence != null) {
      unawaited(_svc.trackTyping(_presence!, false));
    }
    _scrollToBottom();
  }

  void _onTypingChanged(String _) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (_presence == null) return;
      try {
        await _svc.trackTyping(_presence!, _controller.text.isNotEmpty);
      } catch (_) {}
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    _loadingOlder = true;
    try {
      final before = _messages.first.createdAt;
      final older = await _svc.fetchBefore(widget.conversationId, before, limit: 30);
      if (older.isNotEmpty) {
        setState(() => _messages = [...older, ..._messages]);
        for (final m in older) {
          _enqueueDecrypt(m);
        }
      }
    } catch (_) {} finally {
      _loadingOlder = false;
    }
  }

  // küçük yardımcı ui
  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF007AFF);
    final composerDisabled = _isDm && (_iBlocked || _blockedMe);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: themeBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock, size: 14, color: Colors.black54),
                SizedBox(width: 4),
                Text('End-to-End encrypted',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
      body: Column(
        children: [
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
                ],
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels <= 24) _loadOlder();
                return false;
              },
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
                  IconButton(
                    icon: const Icon(Icons.add, color: themeBlue),
                    onPressed: _isDm && (_iBlocked || _blockedMe) ? null : () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _isDm && (_iBlocked || _blockedMe) ? null : _onTypingChanged,
                      enabled: !(_isDm && (_iBlocked || _blockedMe)),
                      decoration: InputDecoration(
                        hintText: _isDm && (_iBlocked || _blockedMe) ? 'Messaging disabled' : 'Type a message…',
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
                    onTap: _isDm && (_iBlocked || _blockedMe) ? null : _send,
                    child: Opacity(
                      opacity: _isDm && (_iBlocked || _blockedMe) ? 0.5 : 1,
                      child: Container(
                        width: 38,
                        height: 38,
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
