import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';
import '../services/social_service.dart'; // ✅ add this import

enum SocialTab { explore, friends }

class SocialViewModel extends ChangeNotifier {
  final SocialRepository repository;
  final SocialService service; // ✅ added service dependency

  final TextEditingController composerController = TextEditingController();
  final List<String> pendingImagePaths = [];

  SocialTab currentTab = SocialTab.explore;
  bool isPosting = false;
  bool isLoading = false;
  bool isEditing = false;
  String? editingPostId;

  List<Post> feed = [];
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};
  final Set<String> _likedByMe = {};
  final Map<String, int> _commentLikeCounts = {};
  final Set<String> _commentLikedByMe = {};
  final Map<String, String> _userNames = {};
  final Map<String, SocialUser> _friends = {};

  SocialViewModel({
    required this.repository,
    required this.service, // ✅ new parameter
  });


  // Hashtag suggestion cache (prefetched from Supabase)
  // Ordered: most recent first, then most used.
  // Each item is a tuple-like map: {tag, lastUsed, count}
  List<({String tag, DateTime lastUsed, int count})> _hashtagIndex = [];

 

  String get meId => Supabase.instance.client.auth.currentUser?.id ?? 'me-local';
  final _supa = Supabase.instance.client;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      // Ensure current user exists & has a human-readable name
      final me = await repository.getUser(meId);
      if (me == null) {
        // Prefer profiles.name + surname; fallback to email prefix; final fallback "User"
        try {
          final prof = await _supa
              .from('profiles')
              .select('name, surname, display_name, full_name, username, email, avatar_url')
              .eq('id', meId)
              .maybeSingle();

          String display = 'User';
          if (prof != null) {
            final map = Map<String, dynamic>.from(prof as Map);
            final name = (map['name'] as String?)?.trim();
            final surname = (map['surname'] as String?)?.trim();
            final displayName = (map['display_name'] as String?)?.trim();
            final fullName = (map['full_name'] as String?)?.trim();
            final username = (map['username'] as String?)?.trim();
            final email = (map['email'] as String?)?.trim();

            display = _pickName(
              name: name,
              surname: surname,
              displayName: displayName,
              fullName: fullName,
              username: username,
              email: email,
            );
            final avatar = (map['avatar_url'] as String?);
            await repository.upsertUser(SocialUser(id: meId, displayName: display, avatarUrl: avatar));
          } else {
            final email = _supa.auth.currentUser?.email;
            final fb = (email != null && email.isNotEmpty) ? email.split('@').first : 'User';
            await repository.upsertUser(SocialUser(id: meId, displayName: fb));
          }
        } catch (_) {
          final email = _supa.auth.currentUser?.email;
          final fb = (email != null && email.isNotEmpty) ? email.split('@').first : 'User';
          await repository.upsertUser(SocialUser(id: meId, displayName: fb));
        }
      } else {
        // If cached name was placeholder, refresh it from profiles
        if (me.displayName.isEmpty || me.displayName == 'User' || me.displayName == 'Kullanıcı') {
          try {
            final prof = await _supa
                .from('profiles')
                .select('name, surname, display_name, full_name, username, email, avatar_url')
                .eq('id', meId)
                .maybeSingle();
            if (prof != null) {
              final map = Map<String, dynamic>.from(prof as Map);
              final name = (map['name'] as String?)?.trim();
              final surname = (map['surname'] as String?)?.trim();
              final displayName = (map['display_name'] as String?)?.trim();
              final fullName = (map['full_name'] as String?)?.trim();
              final username = (map['username'] as String?)?.trim();
              final email = (map['email'] as String?)?.trim();
              final avatar = (map['avatar_url'] as String?);

              final display = _pickName(
                name: name,
                surname: surname,
                displayName: displayName,
                fullName: fullName,
                username: username,
                email: email,
              );
              await repository.upsertUser(SocialUser(id: meId, displayName: display, avatarUrl: avatar ?? me.avatarUrl));
            }
          } catch (_) {/* ignore */}
        }
      }

      // Load feed
      feed = currentTab == SocialTab.explore
          ? await repository.listExplore()
          : await repository.listFriendsFeed(meId);

      // Refresh counts and like state
      _likeCounts.clear();
      _commentCounts.clear();
      _likedByMe.clear();
      _commentLikeCounts.clear();
      _commentLikedByMe.clear();
      _userNames.clear();

      for (final p in feed) {
        final likes = await repository.getLikes(p.id);
        _likeCounts[p.id] = likes.length;
        if (likes.any((l) => l.userId == meId)) {
          _likedByMe.add(p.id);
        }

        final comments = await repository.getComments(p.id);
        _commentCounts[p.id] = comments.length;

        // comment likes for top-level + replies
        for (final c in comments) {
          final cl = await repository.getCommentLikes(c.id);
          _commentLikeCounts[c.id] = cl.length;
          if (cl.any((l) => l.userId == meId)) {
            _commentLikedByMe.add(c.id);
          }

          final replies = await repository.getReplies(c.id);
          for (final r in replies) {
            final rl = await repository.getCommentLikes(r.id);
            _commentLikeCounts[r.id] = rl.length;
            if (rl.any((l) => l.userId == meId)) {
              _commentLikedByMe.add(r.id);
            }
          }
        }

        // Cache names
        _userNames[p.authorId] = (await repository.getUser(p.authorId))?.displayName ?? 'User';
        if (comments.isNotEmpty) {
          final first = comments.first;
          _userNames[first.authorId] =
              (await repository.getUser(first.authorId))?.displayName ?? 'User';
        }
      }

      // Load friends (for @mention suggestions)
      final friendIds = await repository.listFriendIds(meId);
      final friendUsers = await repository.getUsersByIds(friendIds);
      _friends
        ..clear()
        ..addEntries(friendUsers.map((u) => MapEntry(u.id, u)));

      // Cache my name
      final currentUser = await repository.getUser(meId);
      if (currentUser != null) {
        _userNames[meId] = currentUser.displayName;
      }

      // Prefetch hashtags from Supabase to support synchronous suggestions
      await _prefetchHashtags();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _prefetchHashtags() async {
    try {
      final rows = await _supa
          .from('hashtags')
          .select('name, usage_count, last_used_at')
          .order('last_used_at', ascending: false)
          .order('usage_count', ascending: false)
          .limit(100);

      final list = <({String tag, DateTime lastUsed, int count})>[];
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final name = (m['name'] as String).trim();
        final count = (m['usage_count'] as int?) ?? 0;
        final luRaw = m['last_used_at'];
        final lastUsed = (luRaw is String) ? DateTime.tryParse(luRaw) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0);
        list.add((tag: name, lastUsed: lastUsed, count: count));
      }
      _hashtagIndex = list;
    } catch (_) {
      // If Supabase is not available for any reason, keep whatever we had.
      // UI will still work with previous cache or empty suggestions.
    }
  }

  Future<void> switchTab(SocialTab tab) async {
    if (currentTab == tab) return;
    currentTab = tab;
    await load();
  }

  Future<void> postNow() async {
    if (isPosting) return;
    final text = composerController.text.trim();
    if (text.isEmpty && pendingImagePaths.isEmpty) return;

    isPosting = true;
    notifyListeners();
    try {
      await repository.createPost(
        authorId: meId,
        content: text,
        imagePaths: List.of(pendingImagePaths),
      );
      composerController.clear();
      pendingImagePaths.clear();
      await load();
    } finally {
      isPosting = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(Post post) async {
    final wasLiked = _likedByMe.contains(post.id);
    if (wasLiked) {
      _likedByMe.remove(post.id);
      _likeCounts.update(post.id, (v) => (v - 1).clamp(0, 1 << 30), ifAbsent: () => 0);
      notifyListeners();
      try {
        await repository.unlikePost(postId: post.id, userId: meId);
      } catch (_) {
        _likedByMe.add(post.id);
        _likeCounts.update(post.id, (v) => v + 1, ifAbsent: () => 1);
        notifyListeners();
      }
    } else {
      _likedByMe.add(post.id);
      _likeCounts.update(post.id, (v) => v + 1, ifAbsent: () => 1);
      notifyListeners();
      try {
        await repository.likePost(postId: post.id, userId: meId);
      } catch (_) {
        _likedByMe.remove(post.id);
        _likeCounts.update(post.id, (v) => (v - 1).clamp(0, 1 << 30), ifAbsent: () => 0);
        notifyListeners();
      }
    }
  }

  Future<void> addComment(Post post, String content) async {
    final text = content.trim();
    if (text.isEmpty) return;

    _commentCounts.update(post.id, (v) => v + 1, ifAbsent: () => 1);
    notifyListeners();
    try {
      await repository.addComment(postId: post.id, authorId: meId, content: text);
    } catch (_) {
      _commentCounts.update(post.id, (v) => (v - 1).clamp(0, 1 << 30), ifAbsent: () => 0);
      notifyListeners();
    }
  }

  Future<void> addReply(Comment parent, String content) async {
    final text = content.trim();
    if (text.isEmpty) return;

    _commentCounts.update(parent.postId, (v) => v + 1, ifAbsent: () => 1);
    notifyListeners();
    try {
      await repository.addReply(
        postId: parent.postId,
        parentCommentId: parent.id,
        authorId: meId,
        content: text,
      );
    } catch (_) {
      _commentCounts.update(parent.postId, (v) => (v - 1).clamp(0, 1 << 30), ifAbsent: () => 0);
      notifyListeners();
    }
  }

  Future<List<SocialUser>> mentionSuggestions(String query) {
    final q = query.toLowerCase();
    return Future.value(
      _friends.values.where((u) => u.displayName.toLowerCase().contains(q)).take(10).toList(),
    );
  }

  // Synchronous hashtag suggestions from prefetched index
  // Requirement: show most current first, most used first.
  List<String> hashtagSuggestions(String query) {
    final q = query.toLowerCase();
    if (q.isEmpty || _hashtagIndex.isEmpty) return const <String>[];

    final filtered = _hashtagIndex
        .where((e) => e.tag.toLowerCase().startsWith(q))
        .toList()
      ..sort((a, b) {
        final cmpTime = b.lastUsed.compareTo(a.lastUsed); // newer first
        if (cmpTime != 0) return cmpTime;
        return b.count.compareTo(a.count); // more used first
      });

    return filtered.take(10).map((e) => e.tag).toList();
  }

  void reorderPendingImages(int from, int to) {
    if (from == to) return;
    if (from < 0 || to < 0) return;
    if (from >= pendingImagePaths.length || to >= pendingImagePaths.length) return;
    final tmp = pendingImagePaths[from];
    pendingImagePaths[from] = pendingImagePaths[to];
    pendingImagePaths[to] = tmp;
    notifyListeners();
  }

  bool canMentionAllNames(Iterable<String> names) {
    final friendNames = _friends.values.map((u) => u.displayName).toSet();
    final myName = _userNames[meId] ?? 'User';

    for (final n in names) {
      if (n == myName) continue; // allow self mention
      if (!friendNames.contains(n)) return false;
    }
    return true;
  }

  Map<String, String> get friendNameToId =>
      {for (final e in _friends.entries) e.value.displayName: e.key};

  List<String> extractMentionNames(String text) {
    final regex = RegExp(r'@([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ.]+)');
    return [for (final m in regex.allMatches(text)) m.group(1)!];
  }

  bool isFriendName(String name) => friendNameToId.containsKey(name);

  int likeCount(String postId) => _likeCounts[postId] ?? 0;
  int commentCount(String postId) => _commentCounts[postId] ?? 0;
  bool isLikedByMePost(String postId) => _likedByMe.contains(postId);

  // Backward-compat helpers used in some views
  bool isLikedByMe(String postId) => _likedByMe.contains(postId);

  String userName(String userId) => _userNames[userId] ?? 'User';

  String compactCount(int n) {
    if (n >= 1000000) {
      final v = (n / 1000000);
      return '${v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',')} M';
    }
    if (n >= 1000) {
      final v = (n / 1000);
      return '${v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',')} K';
    }
    return n.toString();
  }

  String timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo';
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }

  Future<List<SocialUser>> likers(String postId) async {
    final likes = await repository.getLikes(postId);
    final ids = likes.map((e) => e.userId).toList();
    final users = await repository.getUsersByIds(ids);
    for (final u in users) {
      _userNames[u.id] = u.displayName;
    }
    return users;
  }

  int commentLikeCountLocal(String commentId) => _commentLikeCounts[commentId] ?? 0;
  bool isCommentLikedByMeLocal(String commentId) => _commentLikedByMe.contains(commentId);

  Future<void> toggleCommentLike(String commentId) async {
    final isLiked = _commentLikedByMe.contains(commentId);
    final currentCount = _commentLikeCounts[commentId] ?? 0;

    // Optimistic
    if (isLiked) {
      _commentLikedByMe.remove(commentId);
      _commentLikeCounts[commentId] = (currentCount - 1).clamp(0, 1 << 30);
      notifyListeners();
      try {
        await repository.unlikeComment(commentId: commentId, userId: meId);
      } catch (_) {
        // rollback
        _commentLikedByMe.add(commentId);
        _commentLikeCounts[commentId] = currentCount;
        notifyListeners();
      }
    } else {
      _commentLikedByMe.add(commentId);
      _commentLikeCounts[commentId] = currentCount + 1;
      notifyListeners();
      try {
        await repository.likeComment(commentId: commentId, userId: meId);
      } catch (_) {
        _commentLikedByMe.remove(commentId);
        _commentLikeCounts[commentId] = currentCount;
        notifyListeners();
      }
    }
  }

  Future<List<SocialUser>> commentLikers(String commentId) async {
    final likes = await repository.getCommentLikes(commentId);
    final ids = likes.map((e) => e.userId).toList();
    final users = await repository.getUsersByIds(ids);
    for (final u in users) {
      _userNames[u.id] = u.displayName;
    }
    return users;
  }

  void startEditPost(Post post) {
    isEditing = true;
    editingPostId = post.id;
    composerController.text = post.content;
    pendingImagePaths
      ..clear()
      ..addAll(post.imagePaths);
    notifyListeners();
  }

  void cancelEdit() {
    isEditing = false;
    editingPostId = null;
    composerController.clear();
    pendingImagePaths.clear();
    notifyListeners();
  }

  Future<void> updatePost() async {
    if (!isEditing || editingPostId == null) return;

    isPosting = true;
    notifyListeners();

    try {
      final existingIndex = feed.indexWhere((p) => p.id == editingPostId);
      final existing = existingIndex != -1 ? feed[existingIndex] : null;
      final post = Post(
        id: editingPostId!,
        authorId: existing?.authorId ?? meId,
        content: composerController.text.trim(),
        imagePaths: List.from(pendingImagePaths),
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      await repository.updatePost(post);

      if (existingIndex != -1) {
        feed[existingIndex] = post;
      }

      cancelEdit();
    } finally {
      isPosting = false;
      notifyListeners();
    }
  }

  // inside class SocialViewModel

Future<void> deletePostById(String postId) async {
  // 1) delete on server
  await repository.deletePost(postId);

  // 2) remove from local state (both feeds if you keep two, or the single feed)
  // If you have separate lists like exploreFeed / friendsFeed, remove in both.
  try {
    feed.removeWhere((p) => p.id == postId);
  } catch (_) {}

  // if you track separate caches:
  // exploreFeed.removeWhere((p) => p.id == postId);
  // friendsFeed.removeWhere((p) => p.id == postId);

  // 3) clean any local counters/caches you keep
  try {
    _likeCounts.remove(postId);
    _commentCounts.remove(postId);
  } catch (_) {}

  // 4) notify UI so the card disappears immediately
  notifyListeners();
}


  Future<void> deleteCommentById(String commentId) async {
    try {
      // Delete replies first to avoid FK/RLS issues
      final replies = await repository.getReplies(commentId);
      for (final reply in replies) {
        await repository.deleteComment(reply.id);
        _commentLikeCounts.remove(reply.id);
        _commentLikedByMe.remove(reply.id);
      }

      await repository.deleteComment(commentId);
      _commentLikeCounts.remove(commentId);
      _commentLikedByMe.remove(commentId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateComment(Comment comment) async {
    try {
      await repository.updateComment(comment);
      notifyListeners();
    } catch (_) {/* ignore */}
  }

  String _pickName({
    String? name,
    String? surname,
    String? displayName,
    String? fullName,
    String? username,
    String? email,
  }) {
    final candidates = <String?>[
      // Prefer explicit name + surname if present
      ((name?.isNotEmpty ?? false) || (surname?.isNotEmpty ?? false))
          ? [name, surname].where((s) => s != null && s!.isNotEmpty).join(' ').trim()
          : null,
      displayName,
      fullName,
      username,
      email,
    ];
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) {
        final v = c.trim();
        if (v.contains('@')) return v.split('@').first;
        return v;
      }
    }
    return 'User';
  }

  @override
  void dispose() {
    composerController.dispose();
    super.dispose();
  }
}
