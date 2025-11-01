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

  Future<String?> _pendingFriendshipId(String senderId) async {
    final row = await supa
        .from('friendships')
        .select('id')
        .eq('requester_id', senderId)
        .eq('addressee_id', meId)
        .eq('status', 'pending')
        .maybeSingle();
    return (row == null) ? null : (row['id'] as String?);
  }

  Future<void> _handleFriendRequest(Map<String, dynamic> n, {required bool accept}) async {
    final senderId = n['sender_id'] as String;
    final fid = await _pendingFriendshipId(senderId);
    if (fid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request not found or already handled.')),
        );
      }
      return;
    }

    try {
      await widget.repository.respondFriendRequest(requestId: fid, accept: accept);
      await widget.repository.markNotificationRead(n['id']);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Friend request accepted' : 'Friend request declined')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
                itemBuilder: (context, i) {
                  final n = _items[i];
                  final s = n['sender'] ?? {};
                  final displayName = (s['display_name'] ?? '').toString().trim();
                  final name = (s['name'] ?? '').toString().trim();
                  final surname = (s['surname'] ?? '').toString().trim();
                  String senderName = displayName.isNotEmpty
                      ? displayName
                      : [name, surname].where((e) => e.isNotEmpty).join(' ').trim();
                  if (senderName.isEmpty) senderName = 'User';

                  final avatar = (s['avatar_url'] ?? '').toString();
                  final type = (n['type'] ?? '').toString();
                  final created =
                      DateTime.tryParse((n['created_at'] ?? '').toString()) ?? DateTime.now();

                  // Friend request tile with inline Accept / Decline
                  if (type == 'friend_request') {
  return FutureBuilder(
    future: _pendingFriendshipId(n['sender_id'] as String),
    builder: (context, snapshot) {
      final isPending = snapshot.connectionState == ConnectionState.done &&
          snapshot.data != null;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 10),

            // Expanded text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$senderName sent you a friend request',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Buttons only if still pending
            if (isPending)
              Wrap(
                spacing: 6,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(60, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _handleFriendRequest(n, accept: false),
                    child: const Text('Decline', style: TextStyle(fontSize: 13)),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(60, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => _handleFriendRequest(n, accept: true),
                    child: const Text('Accept', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}


                  // Default tile for like / comment (tap to open)
                  String text;
                  switch (type) {
                    case 'like':
                      text = '$senderName liked your post';
                      break;
                    case 'comment':
                      text = '$senderName commented on your post';
                      break;
                    case 'reply':
                         text = '$senderName replied to your comment';
                    break;
                    default:
                      text = '$senderName performed an action';
                      break;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(text),
                    subtitle: Text(
                      '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () async {
                      await widget.repository.markNotificationRead(n['id']);
                      if (n['post_id'] != null) {
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
