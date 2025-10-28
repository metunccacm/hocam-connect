import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/social_user.dart';
import '../models/social_models.dart';

abstract class SocialRepository {
  Future<SocialUser> upsertUser(SocialUser user);
  Future<SocialUser?> getUser(String userId);
  Future<List<SocialUser>> getUsersByIds(List<String> userIds);
  Future<List<Post>> listExplore();
  Future<List<Post>> listFriendsFeed(String meId);
  Future<Post> createPost({required String authorId, required String content, required List<String> imagePaths});
  Future<void> updatePost(Post post);
  Future<void> deletePost(String postId);
  Future<void> deleteComment(String commentId);
  Future<void> likePost({required String postId, required String userId});
  Future<void> unlikePost({required String postId, required String userId});
  Future<List<Like>> getLikes(String postId);
  Future<Comment> addComment({required String postId, required String authorId, required String content});
  Future<List<Comment>> getComments(String postId);
  Future<Comment> addReply({required String postId, required String parentCommentId, required String authorId, required String content});
  Future<List<Comment>> getReplies(String parentCommentId);
  Future<List<SocialUser>> suggestUsers(String query);
  Future<void> sendFriendRequest({required String fromUserId, required String toUserId});
  Future<void> respondFriendRequest({required String requestId, required bool accept});
  Future<List<String>> listFriendIds(String meId);
  Future<void> likeComment({required String commentId, required String userId});
  Future<void> unlikeComment({required String commentId, required String userId});
  Future<List<CommentLike>> getCommentLikes(String commentId);
  Future<void> updateComment(Comment comment);
  Future<void> clearAllData();
}

class LocalHiveSocialRepository implements SocialRepository {
  static const String usersBox = 'social_users';
  static const String postsBox = 'social_posts';
  static const String commentsBox = 'social_comments';
  static const String likesBox = 'social_likes';
  static const String commentLikesBox = 'social_comment_likes';
  static const String friendshipsBox = 'social_friendships';

  final Uuid _uuid = const Uuid();

  Box<SocialUser> get _users => Hive.box<SocialUser>(usersBox);
  Box<Post> get _posts => Hive.box<Post>(postsBox);
  Box<Comment> get _comments => Hive.box<Comment>(commentsBox);
  Box<Like> get _likes => Hive.box<Like>(likesBox);
  Box<CommentLike> get _commentLikes => Hive.box<CommentLike>(commentLikesBox);
  Box<Friendship> get _friendships => Hive.box<Friendship>(friendshipsBox);

  @override
  Future<SocialUser> upsertUser(SocialUser user) async {
    await _users.put(user.id, user);
    return user;
  }

  @override
  Future<SocialUser?> getUser(String userId) async {
    return _users.get(userId);
  }

  @override
  Future<List<SocialUser>> getUsersByIds(List<String> userIds) async {
    final set = userIds.toSet();
    return _users.values.where((u) => set.contains(u.id)).toList();
  }

  @override
  Future<List<Post>> listExplore() async {
    final items = _posts.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<List<Post>> listFriendsFeed(String meId) async {
    final friendIds = await listFriendIds(meId);
    final set = friendIds.toSet();
    final items = _posts.values.where((p) => set.contains(p.authorId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<Post> createPost({required String authorId, required String content, required List<String> imagePaths}) async {
    final id = _uuid.v4();
    final post = Post(
      id: id,
      authorId: authorId,
      content: content,
      imagePaths: imagePaths,
      createdAt: DateTime.now(),
    );
    await _posts.put(id, post);
    return post;
  }

  @override
  Future<void> updatePost(Post post) async {
    await _posts.put(post.id, post);
  }

  @override
  Future<void> deletePost(String postId) async {
    await _posts.delete(postId);
    // Also delete related comments and likes
    final comments = _comments.values.where((c) => c.postId == postId).toList();
    for (final comment in comments) {
      await _comments.delete(comment.id);
    }
    final likes = _likes.values.where((l) => l.postId == postId).toList();
    for (final like in likes) {
      await _likes.delete(like.id);
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _comments.delete(commentId);
    // Also delete related comment likes
    final commentLikes = _commentLikes.values.where((l) => l.commentId == commentId).toList();
    for (final like in commentLikes) {
      await _commentLikes.delete(like.id);
    }
  }

  @override
  Future<void> likePost({required String postId, required String userId}) async {
    final existing = _likes.values.firstWhere(
      (l) => l.postId == postId && l.userId == userId,
      orElse: () => Like(id: '', postId: '', userId: '', createdAt: DateTime(0)),
    );
    if (existing.id.isNotEmpty) return; // already liked

    final like = Like(id: _uuid.v4(), postId: postId, userId: userId, createdAt: DateTime.now());
    await _likes.put(like.id, like);
  }

  @override
  Future<void> unlikePost({required String postId, required String userId}) async {
    final toRemove = _likes.values.firstWhere(
      (l) => l.postId == postId && l.userId == userId,
      orElse: () => Like(id: '', postId: '', userId: '', createdAt: DateTime(0)),
    );
    if (toRemove.id.isEmpty) return;
    await _likes.delete(toRemove.id);
  }

  @override
  Future<List<Like>> getLikes(String postId) async {
    return _likes.values.where((l) => l.postId == postId).toList();
  }

  @override
  Future<Comment> addComment({required String postId, required String authorId, required String content}) async {
    final c = Comment(
      id: _uuid.v4(),
      postId: postId,
      authorId: authorId,
      content: content,
      createdAt: DateTime.now(),
    );
    await _comments.put(c.id, c);
    return c;
  }

  @override
  Future<List<Comment>> getComments(String postId) async {
    final items = _comments.values.where((c) => c.postId == postId && c.parentCommentId == null).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<Comment> addReply({required String postId, required String parentCommentId, required String authorId, required String content}) async {
    final c = Comment(
      id: _uuid.v4(),
      postId: postId,
      authorId: authorId,
      content: content,
      createdAt: DateTime.now(),
      parentCommentId: parentCommentId,
    );
    await _comments.put(c.id, c);
    return c;
  }

  @override
  Future<List<Comment>> getReplies(String parentCommentId) async {
    final items = _comments.values.where((c) => c.parentCommentId == parentCommentId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<List<SocialUser>> suggestUsers(String query) async {
    final q = query.toLowerCase();
    return _users.values.where((u) => u.displayName.toLowerCase().contains(q)).take(10).toList();
  }

  @override
  Future<void> sendFriendRequest({required String fromUserId, required String toUserId}) async {
    final already = _friendships.values.firstWhere(
      (f) => (f.requesterId == fromUserId && f.addresseeId == toUserId) ||
             (f.requesterId == toUserId && f.addresseeId == fromUserId),
      orElse: () => Friendship(id: '', requesterId: '', addresseeId: '', status: FriendshipStatus.pending, createdAt: DateTime(0)),
    );
    if (already.id.isNotEmpty) return; // exists

    final req = Friendship(
      id: _uuid.v4(),
      requesterId: fromUserId,
      addresseeId: toUserId,
      status: FriendshipStatus.pending,
      createdAt: DateTime.now(),
    );
    await _friendships.put(req.id, req);
  }

  @override
  Future<void> respondFriendRequest({required String requestId, required bool accept}) async {
    final req = _friendships.get(requestId);
    if (req == null) return;
    final updated = Friendship(
      id: req.id,
      requesterId: req.requesterId,
      addresseeId: req.addresseeId,
      status: accept ? FriendshipStatus.accepted : FriendshipStatus.rejected,
      createdAt: req.createdAt,
    );
    await _friendships.put(requestId, updated);
  }

  @override
  Future<List<String>> listFriendIds(String meId) async {
    final accepted = _friendships.values.where((f) => f.status == FriendshipStatus.accepted);
    final ids = <String>[];
    for (final f in accepted) {
      if (f.requesterId == meId) ids.add(f.addresseeId);
      if (f.addresseeId == meId) ids.add(f.requesterId);
    }
    return ids;
  }

  @override
  Future<void> likeComment({required String commentId, required String userId}) async {
    final existing = _commentLikes.values.firstWhere(
      (l) => l.commentId == commentId && l.userId == userId,
      orElse: () => CommentLike(id: '', commentId: '', userId: '', createdAt: DateTime.now()),
    );
    if (existing.id.isNotEmpty) return; // already liked
    
    final like = CommentLike(
      id: _uuid.v4(),
      commentId: commentId,
      userId: userId,
      createdAt: DateTime.now(),
    );
    await _commentLikes.put(like.id, like);
  }

  @override
  Future<void> unlikeComment({required String commentId, required String userId}) async {
    final existing = _commentLikes.values.firstWhere(
      (l) => l.commentId == commentId && l.userId == userId,
      orElse: () => CommentLike(id: '', commentId: '', userId: '', createdAt: DateTime.now()),
    );
    if (existing.id.isEmpty) return; // not liked
    await _commentLikes.delete(existing.id);
  }

  @override
  Future<List<CommentLike>> getCommentLikes(String commentId) async {
    return _commentLikes.values.where((l) => l.commentId == commentId).toList();
  }

  @override
  Future<void> updateComment(Comment comment) async {
    await _comments.put(comment.id, comment);
  }

  Future<void> clearAllData() async {
    await _users.clear();
    await _posts.clear();
    await _comments.clear();
    await _likes.clear();
    await _commentLikes.clear();
    await _friendships.clear();
  }
}


