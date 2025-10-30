// lib/views/spost_detail_view.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';

class SPostDetailView extends StatelessWidget {
  final String postId;
  final Post? initialPost;
  final SocialRepository repository;

  const SPostDetailView({
    super.key,
    required this.postId,
    required this.repository,
    this.initialPost,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<_SPostDetailVM>(
      create: (_) => _SPostDetailVM(
        postId: postId,
        initialPost: initialPost,
        repository: repository,
      )..init(),
      child: const _SPostDetailBody(),
    );
  }
}

class _SPostDetailBody extends StatefulWidget {
  const _SPostDetailBody();

  @override
  State<_SPostDetailBody> createState() => _SPostDetailBodyState();
}

class _SPostDetailBodyState extends State<_SPostDetailBody> {
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _replyCtrl = TextEditingController();
  String? _replyToCommentId;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_SPostDetailVM>();
    final post = vm.post;
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: vm.isLoading || post == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: vm.refreshAll,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        // Header
                        Row(
                          children: [
                            FutureBuilder<SocialUser?>(
                              future: vm.repository.getUser(post.authorId),
                              builder: (context, snap) {
                                final u = snap.data;
                                final avatar = u?.avatarUrl;
                                return CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: (avatar != null && avatar.isNotEmpty)
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: (avatar == null || avatar.isEmpty)
                                      ? Icon(Icons.person, color: Colors.blue.shade700)
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vm.userName(post.authorId),
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(vm.timeAgo(post.createdAt),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit' && vm.isMine(post.authorId)) {
                                  // Navigate to edit screen if needed
                                }
                                if (v == 'delete' && vm.isMine(post.authorId)) {
                                  final ok = await _confirm(context, 'Delete post?', 'This cannot be undone.');
                                  if (ok) {
                                    await vm.deletePost();
                                    if (mounted) Navigator.pop(context, true);
                                  }
                                }
                                if (v == 'report' && !vm.isMine(post.authorId)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Thanks for the report.')),
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                if (vm.isMine(post.authorId))
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                if (vm.isMine(post.authorId))
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                if (!vm.isMine(post.authorId))
                                  const PopupMenuItem(value: 'report', child: Text('Report')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _MentionHashtagText(text: post.content, vm: vm),
                        if (post.imagePaths.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _ImagesGridNet(urls: post.imagePaths),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                vm.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                                color: vm.isLikedByMe ? Colors.red : null,
                              ),
                              onPressed: vm.toggleLike,
                            ),
                            Text(vm.compactCount(vm.likeCount)),
                            const SizedBox(width: 16),
                            const Icon(Icons.mode_comment_outlined),
                            const SizedBox(width: 4),
                            Text(vm.compactCount(vm.totalComments)),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 4),
                        if (vm.comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Be the first to comment.'),
                          )
                        else
                          ...vm.comments.map(
                            (c) => _CommentTile(
                              comment: c,
                              vm: vm,
                              onReplyTap: () {
                                _replyCtrl.text = '@${vm.userName(c.authorId)} ';
                                setState(() => _replyToCommentId = c.id);
                              },
                              onDeleted: () => setState(() {}),
                            ),
                          ),
                        const SizedBox(height: 80),
                      ],
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
                        Expanded(
                          child: (_replyToCommentId == null)
                              ? TextField(
                                  controller: _commentCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Write a comment',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                )
                              : TextField(
                                  controller: _replyCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Write a reply',
                                    border: const OutlineInputBorder(),
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => setState(() {
                                        _replyToCommentId = null;
                                        _replyCtrl.clear();
                                      }),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: vm.isBusy
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send),
                          onPressed: vm.isBusy
                              ? null
                              : () async {
                                  if (_replyToCommentId == null) {
                                    final t = _commentCtrl.text.trim();
                                    if (t.isEmpty) return;
                                    await vm.addComment(t);
                                    _commentCtrl.clear();
                                  } else {
                                    final t = _replyCtrl.text.trim();
                                    if (t.isEmpty) return;
                                    await vm.addReply(_replyToCommentId!, t);
                                    _replyCtrl.clear();
                                    _replyToCommentId = null;
                                  }
                                  setState(() {});
                                },
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok == true;
  }
}

/* =========================
 * ViewModel
 * ========================= */

class _SPostDetailVM extends ChangeNotifier {
  final String postId;
  final Post? initialPost;
  final SocialRepository repository;

  _SPostDetailVM({
    required this.postId,
    required this.repository,
    this.initialPost,
  });

  final supa = Supabase.instance.client;

  bool isLoading = false;
  bool isBusy = false;

  Post? post;
  List<Comment> comments = [];
  int likeCount = 0;
  bool isLikedByMe = false;

  // NEW: synchronous total comments getter (for UI binding)
  int get totalComments => comments.length;

  String get meId => supa.auth.currentUser?.id ?? '';

  Future<void> init() async {
    try {
      isLoading = true;
      notifyListeners();

      if (initialPost != null) {
        post = initialPost!;
      } else {
        // Fetch post directly (repository has no fetch-by-id)
        final row = await supa
            .from('posts')
            .select('id, author_id, content, image_paths, created_at')
            .eq('id', postId)
            .single();

        post = Post(
          id: row['id'] as String,
          authorId: row['author_id'] as String,
          content: (row['content'] ?? '').toString(),
          imagePaths: (row['image_paths'] as List?)?.cast<String>() ?? const <String>[],
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }

      // Likes
      final likes = await repository.getLikes(post!.id);
      likeCount = likes.length;
      isLikedByMe = likes.any((l) => l.userId == meId);

      // Comments (top-level)
      comments = await repository.getComments(post!.id);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await init();
  }

  // Helpers
  bool isMine(String userId) => userId == meId;

  String userName(String uid) => _userNameCache[uid] ?? 'User';

  final Map<String, String> _userNameCache = {};

  Future<String> resolveUserName(String uid) async {
    if (_userNameCache.containsKey(uid)) return _userNameCache[uid]!;
    final u = await repository.getUser(uid);
    final name = u?.displayName ?? 'User';
    _userNameCache[uid] = name;
    return name;
  }

  String timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
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

  String compactCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // Post like
  Future<void> toggleLike() async {
    if (post == null) return;
    final id = post!.id;
    final was = isLikedByMe;

    // optimistic
    if (was) {
      isLikedByMe = false;
      likeCount = (likeCount - 1).clamp(0, 1 << 30);
      notifyListeners();
      try {
        await repository.unlikePost(postId: id, userId: meId);
      } catch (_) {
        isLikedByMe = true;
        likeCount += 1;
        notifyListeners();
      }
    } else {
      isLikedByMe = true;
      likeCount += 1;
      notifyListeners();
      try {
        await repository.likePost(postId: id, userId: meId);
      } catch (_) {
        isLikedByMe = false;
        likeCount = (likeCount - 1).clamp(0, 1 << 30);
        notifyListeners();
      }
    }
  }

  // Comments
  Future<void> addComment(String text) async {
    if (post == null || text.trim().isEmpty) return;
    isBusy = true;
    notifyListeners();
    try {
      final c = await repository.addComment(postId: post!.id, authorId: meId, content: text.trim());
      comments.add(c);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> addReply(String parentCommentId, String text) async {
    if (post == null || text.trim().isEmpty) return;
    isBusy = true;
    notifyListeners();
    try {
      await repository.addReply(
        postId: post!.id,
        parentCommentId: parentCommentId,
        authorId: meId,
        content: text.trim(),
      );
      // replies are fetched lazily in tiles; you can refresh if needed
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> deletePost() async {
    if (post == null) return;
    await repository.deletePost(post!.id);
  }

  Future<void> deleteComment(String commentId) async {
    // delete replies first
    final replies = await repository.getReplies(commentId);
    for (final r in replies) {
      await repository.deleteComment(r.id);
    }
    await repository.deleteComment(commentId);
    comments.removeWhere((c) => c.id == commentId);
    notifyListeners();
  }

  Future<void> editComment(Comment comment, String newText) async {
    final updated = Comment(
      id: comment.id,
      postId: comment.postId,
      authorId: comment.authorId,
      content: newText.trim(),
      createdAt: comment.createdAt,
      parentCommentId: comment.parentCommentId,
    );
    await repository.updateComment(updated);
    final idx = comments.indexWhere((c) => c.id == comment.id);
    if (idx >= 0) comments[idx] = updated;
    notifyListeners();
  }

  // Comment likes
  Future<int> commentLikeCount(String commentId) async {
    final list = await repository.getCommentLikes(commentId);
    return list.length;
  }

  Future<bool> isCommentLikedByMe(String commentId) async {
    final list = await repository.getCommentLikes(commentId);
    return list.any((l) => l.userId == meId);
  }

  Future<void> toggleCommentLike(String commentId) async {
    final liked = await isCommentLikedByMe(commentId);
    try {
      if (liked) {
        await repository.unlikeComment(commentId: commentId, userId: meId);
      } else {
        await repository.likeComment(commentId: commentId, userId: meId);
      }
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  // Mention utilities (optional)
  Future<String?> idByDisplayName(String displayName) async {
    final users = await repository.suggestUsers(displayName);
    final found = users.firstWhere(
      (u) => u.displayName.toLowerCase() == displayName.toLowerCase(),
      orElse: () => SocialUser(id: '', displayName: ''),
    );
    return found.id.isEmpty ? null : found.id;
  }
}

/* =========================
 * Widgets
 * ========================= */

class _CommentTile extends StatefulWidget {
  final Comment comment;
  final _SPostDetailVM vm;
  final VoidCallback onReplyTap;
  final VoidCallback onDeleted;

  const _CommentTile({
    required this.comment,
    required this.vm,
    required this.onReplyTap,
    required this.onDeleted,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _isLiked = false;
  int _likeCount = 0;
  List<Comment>? _replies;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final liked = await widget.vm.isCommentLikedByMe(widget.comment.id);
    final cnt = await widget.vm.commentLikeCount(widget.comment.id);
    final replies = await widget.vm.repository.getReplies(widget.comment.id);
    setState(() {
      _isLiked = liked;
      _likeCount = cnt;
      _replies = replies;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final c = widget.comment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: FutureBuilder<SocialUser?>(
            future: vm.repository.getUser(c.authorId),
            builder: (context, snapshot) {
              final u = snapshot.data;
              final avatar = u?.avatarUrl;
              return CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                backgroundImage:
                    (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Icon(Icons.person, color: Colors.blue.shade700)
                    : null,
              );
            },
          ),
          title: Text(vm.userName(c.authorId), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: _MentionHashtagText(text: c.content, vm: vm),
          trailing: Text(vm.timeAgo(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 56, bottom: 6),
          child: Row(
            children: [
              InkWell(
                onTap: () async {
                  await vm.toggleCommentLike(c.id);
                  final liked = await vm.isCommentLikedByMe(c.id);
                  final cnt = await vm.commentLikeCount(c.id);
                  setState(() {
                    _isLiked = liked;
                    _likeCount = cnt;
                  });
                },
                child: Row(
                  children: [
                    Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16, color: _isLiked ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text(_likeCount.toString(),
                        style: TextStyle(
                            fontSize: 12, color: _isLiked ? Colors.red : Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TextButton(onPressed: widget.onReplyTap, child: const Text('Reply')),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit' && vm.isMine(c.authorId)) {
                    final ctrl = TextEditingController(text: c.content);
                    final updated = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Edit comment'),
                        content: TextField(
                          controller: ctrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Update your comment...',
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                              child: const Text('Save')),
                        ],
                      ),
                    );
                    if (updated != null && updated.isNotEmpty && updated != c.content) {
                      await vm.editComment(c, updated);
                      setState(() {});
                    }
                  }
                  if (v == 'delete' && vm.isMine(c.authorId)) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete comment'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await vm.deleteComment(c.id);
                      widget.onDeleted();
                    }
                  }
                  if (v == 'report' && !vm.isMine(c.authorId)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thanks for the report.')),
                    );
                  }
                },
                itemBuilder: (_) => [
                  if (vm.isMine(c.authorId))
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (vm.isMine(c.authorId))
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  if (!vm.isMine(c.authorId))
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                ],
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(left: 56, bottom: 8),
            child: SizedBox(height: 20, child: LinearProgressIndicator()),
          )
        else if (_replies != null && _replies!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Column(
              children: _replies!
                  .map(
                    (r) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: FutureBuilder<SocialUser?>(
                        future: vm.repository.getUser(r.authorId),
                        builder: (context, snapshot) {
                          final u = snapshot.data;
                          final avatar = u?.avatarUrl;
                          return CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage:
                                (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? Icon(Icons.person, size: 16, color: Colors.blue.shade700)
                                : null,
                          );
                        },
                      ),
                      title: Text(vm.userName(r.authorId),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: _MentionHashtagText(text: r.content, vm: vm),
                      trailing: Text(vm.timeAgo(r.createdAt),
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MentionHashtagText extends StatelessWidget {
  final String text;
  final _SPostDetailVM vm;

  const _MentionHashtagText({required this.text, required this.vm});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final combined = RegExp(r'(@|#)([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ.]+)');
    int last = 0;

    for (final m in combined.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final sym = m.group(1)!; // @ or #
      final value = m.group(2)!;

      if (sym == '@') {
        spans.add(
          TextSpan(
            text: '@$value',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
            recognizer: (TapGestureRecognizer()
              ..onTap = () async {
                final id = await vm.idByDisplayName(value);
                if (id != null) {
                  // Implement your user profile navigation
                  // Navigator.pushNamed(context, '/user-profile', arguments: {'userId': id});
                }
              }),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '#$value',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
            recognizer: (TapGestureRecognizer()
              ..onTap = () {
                // Implement your hashtag search navigation
                // Navigator.pushNamed(context, '/search', arguments: {'q': '#$value'});
              }),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(text: TextSpan(style: DefaultTextStyle.of(context).style, children: spans));
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
        child: AspectRatio(aspectRatio: 4 / 3, child: Image.network(show[0], fit: BoxFit.cover)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
