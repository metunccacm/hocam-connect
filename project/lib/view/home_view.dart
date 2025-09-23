import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project/widgets/custom_appbar.dart';

import '../services/chat_service.dart';
import 'chat_view.dart';
import 'chat_list_view.dart';
import 'profile_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _svc = ChatService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _svc.ensureMyLongTermKey();
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await Supabase.instance.client.auth.signOut();

    // Navigate to login and remove all previous routes
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  Future<void> _openChatList() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatListView()),
    );
  }

  Future<void> _openProfile() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileView()),
    );
  }

  Future<void> _openNewMessagePicker() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final supa = Supabase.instance.client;
      final me = supa.auth.currentUser!.id;

  final rows = await supa.rpc('list_messaging_users');
  final all = (rows as List).cast<Map<String,dynamic>>();
  final items = all
      .map((r) => (
        uid:  r['user_id'] as String,
        name: (r['display_name'] as String?) ?? '',
        avatar: r['avatar_url'] as String?,
        updatedAt: r['updated_at'] as String?
      ))
      .where((it) => it.uid != me)
      .toList();

      if (!mounted) return;

      String q = '';
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSheet) {
              final filtered = items.where((it) {
                if (q.isEmpty) return true;
                return it.name.toLowerCase().contains(q.toLowerCase());
              }).toList();

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('New message',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search name…',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => setSheet(() => q = v),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final it = filtered[i];
                            return ListTile(
                              leading: it.avatar != null && it.avatar!.isNotEmpty
                                  ? CircleAvatar(backgroundImage: NetworkImage(it.avatar!))
                                  : CircleAvatar(
                                      child: Text(
                                        it.name.isNotEmpty ? it.name[0].toUpperCase() : '?',
                                      ),
                                    ),
                              title: Text(it.name),
                              subtitle: Text(it.uid,
                                  style: const TextStyle(color: Colors.black54)),
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                try {
                                  await _svc.ensureMyLongTermKey();
                                  final convId =
                                      await _svc.createOrGetDm(it.uid);
                                  if (!mounted) return;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatView(
                                        conversationId: convId,
                                        title: it.name, // use display name
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Failed to start chat: $e')),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load users: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      heroTag: 'home_new_message_fab',
      onPressed: _openNewMessagePicker,
      icon: const Icon(Icons.message_outlined),
      label: const Text('New message'),
    );

    return Scaffold(
      appBar: HCAppBar(
        title: 'Home Screen',
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Chats',
            onPressed: _openChatList,
          ),
          IconButton(
            icon: const Icon(Icons.message_outlined),
            tooltip: 'New message',
            onPressed: _openNewMessagePicker,
          ),
          IconButton(
            icon: const Icon(Icons.account_box),
            tooltip: 'Profile',
            onPressed: _openProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: fab,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yemekhane Menüsü Butonu
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/canteen-menu');
                },
                icon: const Icon(Icons.restaurant_menu, size: 24),
                label: const Text(
                  'Yemekhane Menüsü',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
