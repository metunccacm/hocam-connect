// lib/views/notifications_view.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/social_service.dart';
import '../services/social_repository.dart';
import 'spost_detail_view.dart';


class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final supa = Supabase.instance.client;
  final _service = SocialService();
  final _repo = SupabaseSocialRepository();

  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Uses the same select shape as in SocialService.getNotifications()
      final result = await supa
          .from('notifications')
          .select('''
            id,
            type,
            is_read,
            created_at,
            user_id,
            action_user_id,
            post_id,
            comment_id,
            action_user:profiles!action_user_id(name, surname, avatar_url),
            post:posts(content),
            comment:comments(content)
          ''')
          .eq('user_id', supa.auth.currentUser!.id)
          .order('created_at', ascending: false);

      setState(() {
        _items = List<Map<String, dynamic>>.from(result as List);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _titleFor(Map<String, dynamic> n) {
    final au = (n['action_user'] as Map?) ?? {};
    final name = ((au['name'] ?? '') as String).trim();
    final surname = ((au['surname'] ?? '') as String).trim();
    final display = [name, surname].where((s) => s.isNotEmpty).join(' ').trim();
    final actor = display.isEmpty ? 'Someone' : display;

    final type = (n['type'] ?? '').toString();
    switch (type) {
      case 'like':
        return '$actor liked your post';
      case 'comment':
        return '$actor commented on your post';
      case 'reply':
        return '$actor replied to your comment';
      case 'mention':
        return '$actor mentioned you';
      case 'follow':
        return '$actor started following you';
      default:
        return '$actor did something';
    }
  }

  String _subtitleFor(Map<String, dynamic> n) {
    final post = n['post'] as Map?;
    final comment = n['comment'] as Map?;
    if (comment != null && (comment['content'] ?? '').toString().isNotEmpty) {
      return comment['content'].toString();
    }
    if (post != null && (post['content'] ?? '').toString().isNotEmpty) {
      return post['content'].toString();
    }
    return '';
  }

  Future<void> _markRead(String id) async {
    await supa.from('notifications').update({'is_read': true}).eq('id', id);
    // local refresh
    final idx = _items.indexWhere((e) => e['id'] == id);
    if (idx >= 0) {
      setState(() {
        _items[idx] = {..._items[idx], 'is_read': true};
      });
    }
  }

  void _openTarget(Map<String, dynamic> n) {
    final postId = n['post_id'] as String?;
    if (postId != null && postId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SPostDetailView(
            postId: postId,
            repository: _repo,
          ),
        ),
      );
    }
    // You can add navigation for comment-only notifications if needed.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_items.any((e) => e['is_read'] == false))
            TextButton(
              onPressed: () async {
                await supa
                    .from('notifications')
                    .update({'is_read': true})
                    .eq('user_id', supa.auth.currentUser!.id)
                    .eq('is_read', false);
                _load();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = _items[i];
                  final au = (n['action_user'] as Map?) ?? {};
                  final avatarUrl = (au['avatar_url'] ?? '').toString();
                  final isRead = n['is_read'] == true;

                  return ListTile(
                    onTap: () {
                      _openTarget(n);
                      if (!isRead) _markRead(n['id'].toString());
                    },
                    leading: CircleAvatar(
                      backgroundImage:
                          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child:
                          avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(
                      _titleFor(n),
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w700,
                      ),
                    ),
                    subtitle: Builder(
  builder: (_) {
    final s = _subtitleFor(n);
    if (s.isEmpty) {
      return const SizedBox.shrink(); // ✅ return empty widget instead of null
    }
    return Text(
      s,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  },
),

                    trailing: isRead
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Mark as read',
                            icon: const Icon(Icons.check),
                            onPressed: () => _markRead(n['id'].toString()),
                          ),
                  );
                },
              ),
            ),
    );
  }
}
