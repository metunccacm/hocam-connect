import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/social_repository.dart';
import 'user_profile_view.dart';
import 'spost_detail_view.dart';

class SocialNotificationsView extends StatefulWidget {
  final SocialRepository repository;
  const SocialNotificationsView({super.key, required this.repository});

  @override
  State<SocialNotificationsView> createState() => _SocialNotificationsViewState();
}

class _SocialNotificationsViewState extends State<SocialNotificationsView> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  final supa = Supabase.instance.client;
  String get meId => supa.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();

    // optional real-time updates
    supa
        .channel('notifications_social_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications_social',
          callback: (payload) {
            if (payload.newRecord['receiver_id'] == meId) _load();
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    final rows = await widget.repository.getNotifications(meId);
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final n = _items[i];
                  final s = n['sender'] ?? {};
                  final displayName = (s['display_name'] ?? '').toString().trim();
                  final name = (s['name'] ?? '').toString().trim();
                  final surname = (s['surname'] ?? '').toString().trim();
                    String senderName = displayName.isNotEmpty
                    ? displayName
                    : [name, surname].where((e) => e.isNotEmpty).join(' ').trim();
                  if (senderName.isEmpty) senderName = 'User';

                  final avatar = s['avatar_url'] ?? '';
                  final type = n['type'];
                  final created = DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now();

                  String text = '';
                  switch (type) {
                    case 'friend_request':
                      text = '$senderName sent you a friend request';
                      break;
                    case 'like':
                      text = '$senderName liked your post';
                      break;
                    case 'comment':
                      text = '$senderName commented on your post';
                      break;
                    default:  
                      text = '$senderName performed an action';
                      break;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(text),
                    subtitle: Text(
                      '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () async {
                      await widget.repository.markNotificationRead(n['id']);

                      if (type == 'friend_request') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileView(
                              userId: n['sender_id'],
                              repository: widget.repository,
                            ),
                          ),
                        );
                      } else if (n['post_id'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SPostDetailView(
                              postId: n['post_id'] as String,
                              repository: widget.repository,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
    );
  }
}
