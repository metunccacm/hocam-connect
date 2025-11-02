import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';
import 'spost_detail_view.dart';

class UserProfileView extends StatefulWidget {
  final String userId;
  final SocialRepository repository;

  const UserProfileView({
    super.key,
    required this.userId,
    required this.repository,
  });

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final supa = Supabase.instance.client;

  bool _loading = true;
  SocialUser? _user;
  String? _department;

  /// 'me' | 'none' | 'pending_outgoing' | 'pending_incoming' | 'friends'
  String _friendState = 'none';
  String? _friendshipId;

  // Posts of this profile
  bool _loadingPosts = true;
  List<Post> _posts = const [];

  String get meId => supa.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    setState(() {
      _loading = true;
      _loadingPosts = true;
    });

    // --- profile basics ---
    _user = await widget.repository.getUser(widget.userId);

    final profile = await supa
        .from('profiles')
        .select('department')
        .eq('id', widget.userId)
        .maybeSingle();
    _department = profile?['department'] as String?;

    // --- friendship state ---
    if (widget.userId == meId) {
      _friendState = 'me';
      _friendshipId = null;
    } else {
      final outgoing = await supa
          .from('friendships')
          .select('id, status')
          .eq('requester_id', meId)
          .eq('addressee_id', widget.userId)
          .maybeSingle();

      final incoming = await supa
          .from('friendships')
          .select('id, status')
          .eq('requester_id', widget.userId)
          .eq('addressee_id', meId)
          .maybeSingle();

      if (outgoing != null) {
        final status = outgoing['status'] as String?;
        _friendshipId = outgoing['id'] as String?;
        if (status == 'accepted') {
          _friendState = 'friends';
        } else if (status == 'pending') {
          _friendState = 'pending_outgoing';
        } else {
          _friendState = 'none';
        }
      } else if (incoming != null) {
        final status = incoming['status'] as String?;
        _friendshipId = incoming['id'] as String?;
        if (status == 'accepted') {
          _friendState = 'friends';
        } else if (status == 'pending') {
          _friendState = 'pending_incoming';
        } else {
          _friendState = 'none';
        }
      } else {
        _friendState = 'none';
        _friendshipId = null;
      }
    }

    // --- user's posts ---
    await _loadPosts();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    try {
      final rows = await supa
          .from('posts')
          .select('id, author_id, content, image_paths, created_at')
          .eq('author_id', widget.userId)
          .order('created_at', ascending: false);

      final list = <Post>[];
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        list.add(
          Post(
            id: m['id'] as String,
            authorId: m['author_id'] as String,
            content: (m['content'] ?? '').toString(),
            imagePaths: (m['image_paths'] as List?)?.cast<String>() ?? const <String>[],
            createdAt: DateTime.parse(m['created_at'] as String),
          ),
        );
      }
      setState(() {
        _posts = list;
      });
    } catch (_) {
      // fail-soft
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    try {
      await widget.repository.sendFriendRequest(
        fromUserId: meId,
        toUserId: widget.userId,
      );
      await _hydrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _cancelOutgoingRequest() async {
    try {
      if (_friendshipId == null) return;
      await supa
          .from('friendships')
          .delete()
          .eq('id', _friendshipId!)
          .eq('requester_id', meId)
          .eq('addressee_id', widget.userId)
          .eq('status', 'pending');
      await _hydrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request cancelled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _acceptIncoming() async {
    try {
      if (_friendshipId == null) return;
      await widget.repository.respondFriendRequest(
        requestId: _friendshipId!,
        accept: true,
      );
      await _hydrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Friend added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _declineIncoming() async {
    try {
      if (_friendshipId == null) return;
      await widget.repository.respondFriendRequest(
        requestId: _friendshipId!,
        accept: false,
      );
      await _hydrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request declined')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _unfriend() async {
    try {
      await supa.from('friendships').delete().or(
            'and(requester_id.eq.$meId,addressee_id.eq.${widget.userId},status.eq.accepted),'
            'and(requester_id.eq.${widget.userId},addressee_id.eq.$meId,status.eq.accepted)',
          );
      await _hydrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unfriended')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final w = (diff.inDays / 7).floor();
    if (w < 5) return '${w}w';
    final mo = (diff.inDays / 30).floor();
    if (mo < 12) return '${mo}mo';
    final y = (diff.inDays / 365).floor();
    return '${y}y';
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = user?.displayName ?? 'User';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      appBar: AppBar(title: Text(name), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _hydrate,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // -------- Profile header --------
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      backgroundColor: Colors.blue.shade100,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Icon(Icons.person, size: 48, color: Colors.blue.shade700)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (_department != null && _department!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_department!,
                          style: const TextStyle(color: Colors.grey)),
                    ],
                    const SizedBox(height: 16),

                    // -------- Friendship controls --------
                    if (_friendState == 'me')
                      const Text('This is your profile',
                          style: TextStyle(color: Colors.grey)),
                    if (_friendState == 'none')
                      FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add Friend'),
                        onPressed: _sendFriendRequest,
                      ),
                    if (_friendState == 'pending_outgoing') ...[
                      const Chip(label: Text('Request Pending')),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Request'),
                        onPressed: _cancelOutgoingRequest,
                      ),
                    ],
                    if (_friendState == 'pending_incoming')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                            onPressed: _acceptIncoming,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Decline'),
                            onPressed: _declineIncoming,
                          ),
                        ],
                      ),
                    if (_friendState == 'friends') ...[
                      const Chip(label: Text('Friends')),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.person_remove_alt_1),
                        label: const Text('Unfriend'),
                        onPressed: _unfriend,
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),

                    // -------- Posts section --------
                    Row(
                      children: const [
                        Text('Posts',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_loadingPosts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      )
                    else if (_posts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No posts yet',
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final p = _posts[i];
                          return InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SPostDetailView(
                                    postId: p.id,
                                    repository: widget.repository,
                                    initialPost: p,
                                  ),
                                ),
                              );
                              // reload in case of edits
                              _loadPosts();
                            },
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // top row with avatar/name/time
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage: (avatarUrl != null &&
                                                  avatarUrl.isNotEmpty)
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          backgroundColor:
                                              Colors.blue.shade100,
                                          child: (avatarUrl == null ||
                                                  avatarUrl.isEmpty)
                                              ? Icon(Icons.person,
                                                  size: 18,
                                                  color:
                                                      Colors.blue.shade700)
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                              Text(
                                                _timeAgo(p.createdAt),
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(p.content),
                                    if (p.imagePaths.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _ImagesGridNet(urls: p.imagePaths),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ImagesGridNet extends StatelessWidget {
  final List<String> urls;
  const _ImagesGridNet({required this.urls});

  @override
  Widget build(BuildContext context) {
    final show = urls.take(4).toList();
    const radius = 8.0;

    Widget tile(int i, {BorderRadius? br}) {
      return ClipRRect(
        borderRadius: br ?? BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(show[i], fit: BoxFit.cover),
        ),
      );
    }

    if (show.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(show[0], fit: BoxFit.cover),
        ),
      );
    }
    if (show.length == 2) {
      return Row(
        children: [
          Expanded(child: tile(0)),
          const SizedBox(width: 6),
          Expanded(child: tile(1)),
        ],
      );
    }
    if (show.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: tile(0)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(child: tile(1)),
                const SizedBox(height: 6),
                Expanded(child: tile(2)),
              ],
            ),
          ),
        ],
      );
    }
    final extra = urls.length - 4;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile(0)),
            const SizedBox(width: 6),
            Expanded(child: tile(1)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: tile(2)),
            const SizedBox(width: 6),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  tile(3),
                  if (extra > 0)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(radius),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+$extra',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
