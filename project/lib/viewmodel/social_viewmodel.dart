import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';

enum SocialTab { explore, friends }

class SocialViewModel extends ChangeNotifier {
  final SocialRepository repository;
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
  final Map<String, String> _userNames = {}; // cache id -> displayName
  final Map<String, SocialUser> _friends = {}; // id -> user (friends only)

  SocialViewModel({required this.repository});

  String get meId => Supabase.instance.client.auth.currentUser?.id ?? 'me-local';

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      // ensure current user exists in local store for display
      final me = await repository.getUser(meId);
      if (me == null) {
        // Try to use Supabase username/email prefix as default display name
        final email = Supabase.instance.client.auth.currentUser?.email;
        final fallback = (email != null && email.isNotEmpty) ? email.split('@').first : 'Kullanıcı';
        await repository.upsertUser(SocialUser(id: meId, displayName: fallback));
      } else if (me.displayName.isEmpty || me.displayName == 'Kullanıcı') {
        // Update existing user with proper display name if missing
        final email = Supabase.instance.client.auth.currentUser?.email;
        final fallback = (email != null && email.isNotEmpty) ? email.split('@').first : 'Kullanıcı';
        await repository.upsertUser(SocialUser(id: meId, displayName: fallback, avatarUrl: me.avatarUrl));
      }

      feed = currentTab == SocialTab.explore
          ? await repository.listExplore()
          : await repository.listFriendsFeed(meId);

      // refresh counts and like state
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

        // load comment likes
        for (final comment in comments) {
          final commentLikes = await repository.getCommentLikes(comment.id);
          _commentLikeCounts[comment.id] = commentLikes.length;
          if (commentLikes.any((l) => l.userId == meId)) {
            _commentLikedByMe.add(comment.id);
          }
          
          // load reply likes
          final replies = await repository.getReplies(comment.id);
          for (final reply in replies) {
            final replyLikes = await repository.getCommentLikes(reply.id);
            _commentLikeCounts[reply.id] = replyLikes.length;
            if (replyLikes.any((l) => l.userId == meId)) {
              _commentLikedByMe.add(reply.id);
            }
          }
        }

        // cache author name
        _userNames[p.authorId] = (await repository.getUser(p.authorId))?.displayName ?? 'Kullanıcı';
        // cache commenters' names (first one enough for feed)
        if (comments.isNotEmpty) {
          final first = comments.first;
          _userNames[first.authorId] = (await repository.getUser(first.authorId))?.displayName ?? 'Kullanıcı';
        }
      }

      // load friends list
      final friendIds = await repository.listFriendIds(meId);
      final friendUsers = await repository.getUsersByIds(friendIds);
      _friends
        ..clear()
        ..addEntries(friendUsers.map((u) => MapEntry(u.id, u)));

      // cache current user's name
      final currentUser = await repository.getUser(meId);
      if (currentUser != null) {
        _userNames[meId] = currentUser.displayName;
      }
    } finally {
      isLoading = false;
      notifyListeners();
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
      await repository.createPost(authorId: meId, content: text, imagePaths: List.of(pendingImagePaths));
      composerController.clear();
      pendingImagePaths.clear();
      await load();
    } finally {
      isPosting = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(Post post) async {
    // optimistic toggle
    final wasLiked = _likedByMe.contains(post.id);
    if (wasLiked) {
      _likedByMe.remove(post.id);
      _likeCounts.update(post.id, (v) => (v - 1).clamp(0, 1 << 30), ifAbsent: () => 0);
      notifyListeners();
      try {
        await repository.unlikePost(postId: post.id, userId: meId);
      } catch (_) {
        // rollback
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
        // rollback
        _likedByMe.remove(post.id);
        _likeCounts.update(post.id, (v) => (v - 1).clamp(0, 1 << 30), ifAbsent: () => 0);
        notifyListeners();
      }
    }
  }

  Future<void> addComment(Post post, String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    // optimistic increment
    _commentCounts.update(post.id, (v) => v + 1, ifAbsent: () => 1);
    notifyListeners();
    try {
      await repository.addComment(postId: post.id, authorId: meId, content: text);
    } catch (_) {
      // rollback
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
      await repository.addReply(postId: parent.postId, parentCommentId: parent.id, authorId: meId, content: text);
    } catch (_) {
      _commentCounts.update(parent.postId, (v) => (v - 1).clamp(0, 1 << 30), ifAbsent: () => 0);
      notifyListeners();
    }
  }

  Future<List<SocialUser>> mentionSuggestions(String query) {
    final q = query.toLowerCase();
    return Future.value(_friends.values
        .where((u) => u.displayName.toLowerCase().contains(q))
        .take(10)
        .toList());
  }

  List<String> hashtagSuggestions(String query) {
    final q = query.toLowerCase();
    // naive: derive from recent posts' hashtags
    final Set<String> tags = {};
    final regex = RegExp(r'#([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ]+)');
    for (final p in feed.take(100)) {
      for (final m in regex.allMatches(p.content)) {
        final tag = m.group(1)!.toLowerCase();
        if (tag.contains(q)) tags.add(tag);
      }
    }
    final list = tags.toList()..sort();
    return list.take(10).toList();
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
    for (final n in names) {
      if (!friendNames.contains(n)) return false;
    }
    return true;
  }

  Map<String, String> get friendNameToId =>
      {for (final e in _friends.entries) e.value.displayName: e.key};

  List<String> extractMentionNames(String text) {
    final regex = RegExp(r'@([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ]+)');
    return [for (final m in regex.allMatches(text)) m.group(1)!];
  }

  bool isFriendName(String name) => friendNameToId.containsKey(name);

  int likeCount(String postId) => _likeCounts[postId] ?? 0;
  int commentCount(String postId) => _commentCounts[postId] ?? 0;
  bool isLikedByMe(String postId) => _likedByMe.contains(postId);
  String userName(String userId) => _userNames[userId] ?? 'Kullanıcı';
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
    if (diff.inSeconds < 60) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '$weeks hf';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months ay';
    final years = (diff.inDays / 365).floor();
    return '$years y';
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

  int commentLikeCount(String commentId) => _commentLikeCounts[commentId] ?? 0;
  bool isCommentLikedByMe(String commentId) => _commentLikedByMe.contains(commentId);

  Future<void> toggleCommentLike(String commentId) async {
    print('toggleCommentLike called for: $commentId');
    final isLiked = _commentLikedByMe.contains(commentId);
    final currentCount = _commentLikeCounts[commentId] ?? 0;
    
    print('Current state - isLiked: $isLiked, count: $currentCount');
    
    // Optimistic update
    if (isLiked) {
      _commentLikedByMe.remove(commentId);
      _commentLikeCounts[commentId] = (currentCount - 1).clamp(0, double.infinity).toInt();
    } else {
      _commentLikedByMe.add(commentId);
      _commentLikeCounts[commentId] = currentCount + 1;
    }
    print('After optimistic update - isLiked: ${_commentLikedByMe.contains(commentId)}, count: ${_commentLikeCounts[commentId]}');
    notifyListeners();
    
    try {
      if (isLiked) {
        print('Calling unlikeComment...');
        await repository.unlikeComment(commentId: commentId, userId: meId);
      } else {
        print('Calling likeComment...');
        await repository.likeComment(commentId: commentId, userId: meId);
      }
      print('Repository call successful');
    } catch (e) {
      print('Repository call failed: $e');
      // Rollback on error
      if (isLiked) {
        _commentLikedByMe.add(commentId);
        _commentLikeCounts[commentId] = currentCount;
      } else {
        _commentLikedByMe.remove(commentId);
        _commentLikeCounts[commentId] = currentCount;
      }
      notifyListeners();
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
    pendingImagePaths.clear();
    pendingImagePaths.addAll(post.imagePaths);
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
      
      // Update local feed
      if (existingIndex != -1) {
        feed[existingIndex] = post;
      }
      
      cancelEdit();
    } catch (e) {
      // Handle error
    } finally {
      isPosting = false;
      notifyListeners();
    }
  }

  Future<void> deletePostById(String postId) async {
    try {
      await repository.deletePost(postId);
      feed.removeWhere((p) => p.id == postId);
      _likeCounts.remove(postId);
      _commentCounts.remove(postId);
      _likedByMe.remove(postId);
      notifyListeners();
    } catch (_) {
      // swallow for now; could surface error snackbar via caller
    }
  }

  @override
  void dispose() {
    composerController.dispose();
    super.dispose();
  }
}


