// lib/view/chat_view.dart
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

  RealtimeChannel? _msgChannel;
  bool _loadingOlder = false;

  // DM blok bayrakları
  bool _isDm = false;
  bool _iBlocked = false;
  bool _blockedMe = false;

  // karşı taraf başlığı (opsiyonel)
  String? _otherDisplayName;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // --- küçük yardımcılar ---
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

  Future<void> _bootstrap() async {
    // Header/DM bilgileri
    unawaited(_loadHeaderMeta());
    unawaited(_loadBlockStatus());

    // İlk mesajlar
    final initial = await _svc.fetchInitial(widget.conversationId, limit: 30);
    setState(() => _messages = initial);

    // realtime: mesaj insertleri
    _msgChannel =
        _svc.subscribeMessages(widget.conversationId, (m) async {
      setState(() => _messages = [..._messages, m]);
      _scrollToBottom();
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
        // basit başlık; istersen display map kullanmaya devam edebilirsin
        _otherDisplayName = 'User ${others.first.substring(0, 6)}';
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

  // --- gönderme ---
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // client-side guard
    if (_isDm && (_iBlocked || _blockedMe)) {
      _show('You cannot send messages in this conversation.');
      return;
    }

    _controller.clear();

    try {
      await _svc.sendText(
        conversationId: widget.conversationId,
        text: text,
      );
    } catch (e) {
      // RLS/permission hatası dahil
      _show('Message not sent: $e');
      return;
    }

    _scrollToBottom();
  }

  // --- daha eski mesajları yükleme
  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    _loadingOlder = true;
    try {
      final before = _messages.first.createdAt;
      final older =
          await _svc.fetchBefore(widget.conversationId, before, limit: 30);
      if (older.isNotEmpty) {
        setState(() => _messages = [...older, ..._messages]);
      }
    } catch (_) {
    } finally {
      _loadingOlder = false;
    }
  }

  // --- OPTIONAL DEBUG ACTION ---
  Future<void> _debugRls() async {
    try {
      final dbg = await Supabase.instance.client.rpc(
        'can_send_debug',
        params: {'_conversation_id': widget.conversationId},
      );
      _show('can_send debug:\n${dbg.toString()}');
    } catch (e) {
      _show('debug rpc failed: $e');
    }
  }

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
                Icon(Icons.chat_bubble_outline, size: 14, color: Colors.black54),
                SizedBox(width: 4),
                Text('Direct Messages',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule, color: Colors.black54),
            tooltip: 'RLS self-check',
            onPressed: _debugRls,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: Column(
        children: [
          // DM bloğu varsa banner
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
                          _show('Unblock failed: $e');
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                ],
              ),
            ),

          // Mesaj listesi
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
                          m.body,
                          style: TextStyle(color: mine ? Colors.white : Colors.black87, fontSize: 16),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Composer
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: themeBlue),
                    onPressed: composerDisabled ? null : () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
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
