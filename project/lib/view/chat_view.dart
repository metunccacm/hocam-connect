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

  // ---- NEW: decrypt queue & cache
  final Map<String, String> _plain = {};
  final List<String> _queue = [];
  bool _decryptRunning = false;

  RealtimeChannel? _msgChannel;
  RealtimeChannel? _presence;
  Set<String> _typing = {};
  Timer? _typingDebounce;
  bool _loadingOlder = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _svc.bootstrapCekIfMissing(widget.conversationId);

    final initial = await _svc.fetchInitial(widget.conversationId, limit: 30);
    setState(() => _messages = initial);
    // ---- decrypt sıraya ekle
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _presence?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  // ---- NEW: queue runner (tek görev)
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
      } catch (e) {
        _plain[id] = '(decrypt failed)';
      }
      if (mounted) setState(() {}); // sadece ilgili balon güncellensin
      // küçük bir nefes — UI’yi rahatlatır
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

  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    _loadingOlder = true;

    final prevMaxExtent =
        _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;

    final older = await _svc.fetchBefore(
      widget.conversationId,
      _messages.first.createdAt,
      limit: 30,
    );

    if (older.isNotEmpty) {
      setState(() => _messages = [...older, ..._messages]);
      for (final m in older) _enqueueDecrypt(m);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final newMaxExtent = _scroll.position.maxScrollExtent;
        final delta = newMaxExtent - prevMaxExtent;
        _scroll.jumpTo(_scroll.position.pixels + delta);
      });
    }
    _loadingOlder = false;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await _svc.sendTextEncrypted(
      conversationId: widget.conversationId,
      text: text,
    );

    if (_presence != null) {
      unawaited(_svc.trackTyping(_presence!, false));
    }
    _scrollToBottom();
  }

  void _onTypingChanged(String _) {
    _typingDebounce?.cancel();
    if (_presence != null) {
      _svc.trackTyping(_presence!, true);
      _typingDebounce = Timer(const Duration(milliseconds: 900), () {
        _svc.trackTyping(_presence!, false);
      });
    }
  }

  bool _isMine(ChatMessage m) =>
      m.senderId == Supabase.instance.client.auth.currentUser!.id;

  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF007AFF);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: themeBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: CircleAvatar(radius: 16),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels <= 24) _loadOlder();
                return false;
              },
              child: ListView.builder(
                controller: _scroll,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final mine = _isMine(m);
                  final text = _plain[m.id]; // null ise henüz çözülmedi
                  if (text == null) _enqueueDecrypt(m);

                  return Container(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                          text ?? '…', // beklerken hafif placeholder
                          style: TextStyle(
                            color: mine ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
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
              child: Text('typing…',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: themeBlue),
                    onPressed: () {
                      // attachment flow (opsiyonel)
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onTypingChanged,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                    onTap: _send,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: themeBlue,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.send, color: Colors.white, size: 18),
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
