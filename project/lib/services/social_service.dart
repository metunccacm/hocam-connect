// lib/services/social_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social_models.dart';
import '../models/social_user.dart';

class SocialService {
  final SupabaseClient _db = Supabase.instance.client;

  /// ---------------------------
  /// USER OPERATIONS
  /// ---------------------------

  Future<SocialUser?> getUser(String userId) async {
    final res = await _db.from('profiles').select().eq('id', userId).maybeSingle();
    if (res == null) return null;
    return SocialUser(
      id: res['id'] as String,
      displayName: res['display_name'] ?? 'Kullanıcı',
      avatarUrl: res['avatar_url'] ?? '',
    );
  }

  Future<void> upsertUser(SocialUser user) async {
    await _db.from('profiles').upsert({
      'id': user.id,
      'display_name': user.displayName,
      'avatar_url': user.avatarUrl ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<SocialUser>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final res = await _db.from('profiles').select().inFilter('id', ids);
    return res.map<SocialUser>((row) {
      return SocialUser(
        id: row['id'] as String,
        displayName: row['display_name'] ?? 'Kullanıcı',
        avatarUrl: row['avatar_url'] ?? '',
      );
    }).toList();
  }

  /// ---------------------------
  /// POST OPERATIONS
  /// ---------------------------

  Future<List<Post>> listExplore() async {
    final res = await _db
        .from('posts')
        .select()
        .order('created_at', ascending: false);
    return res.map<Post>((row) {
      return Post(
        id: row['id'],
        authorId: row['author_id'],
        content: row['content'] ?? '',
        imagePaths: (row['image_paths'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.parse(row['created_at']),
      );
    }).toList();
  }

  Future<List<Post>> listFriendsFeed(String meId) async {
    final friendRows = await _db
        .from('friendships')
        .select()
        .or('requester_id.eq.$meId,addressee_id.eq.$meId')
        .eq('status', 'accepted');

    final friendIds = <String>{};
    for (final f in friendRows) {
      if (f['requester_id'] != meId) friendIds.add(f['requester_id']);
      if (f['addressee_id'] != meId) friendIds.add(f['addressee_id']);
    }

    if (friendIds.isEmpty) return [];

    final res = await _db
        .from('posts')
        .select()
        .inFilter('author_id', friendIds.toList())
        .order('created_at', ascending: false);

    return res.map<Post>((row) {
      return Post(
        id: row['id'],
        authorId: row['author_id'],
        content: row['content'] ?? '',
        imagePaths: (row['image_paths'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.parse(row['created_at']),
      );
    }).toList();
  }

  Future<Post> createPost({
    required String authorId,
    required String content,
    required List<String> imagePaths,
  }) async {
    final hashtags = _extractHashtags(content);
    for (final tag in hashtags) {
      await _db.rpc('upsert_hashtag', params: {'tag_name': tag});
    }

    final mentions = _extractMentions(content);

    final inserted = await _db
        .from('posts')
        .insert({
          'author_id': authorId,
          'content': content,
          'image_paths': imagePaths,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final postId = inserted['id'] as String;

    // Mentions
    for (final userId in mentions) {
      await _db.from('mentions').insert({
        'post_id': postId,
        'mentioned_user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Hashtag links
    for (final tag in hashtags) {
      final tagRow = await _db
          .from('hashtags')
          .select('id')
          .eq('name', tag)
          .maybeSingle();
      if (tagRow != null) {
        await _db.from('post_hashtags').insert({
          'post_id': postId,
          'hashtag_id': tagRow['id'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }

    return Post(
      id: postId,
      authorId: authorId,
      content: content,
      imagePaths: imagePaths,
      createdAt: DateTime.parse(inserted['created_at']),
    );
  }

  Future<void> updatePost(Post post) async {
    final hashtags = _extractHashtags(post.content);
    for (final tag in hashtags) {
      await _db.rpc('upsert_hashtag', params: {'tag_name': tag});
    }

    await _db.from('posts').update({
      'content': post.content,
      'image_paths': post.imagePaths,
    }).eq('id', post.id);
  }

  Future<void> deletePost(String postId) async {
    await _db.from('post_likes').delete().eq('post_id', postId);
    await _db.from('comments').delete().eq('post_id', postId);
    await _db.from('mentions').delete().eq('post_id', postId);
    await _db.from('post_hashtags').delete().eq('post_id', postId);
    await _db.from('bookmarks').delete().eq('post_id', postId);
    await _db.from('post_reports').delete().eq('post_id', postId);
    await _db.from('posts').delete().eq('id', postId);
  }

  /// ---------------------------
  /// POST LIKES
  /// ---------------------------

  // inside class SocialService
Future<void> likePost({required String postId, required String userId}) async {
  // write like (ignore duplicates)
  final exists = await _db
      .from('post_likes')
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', userId)
      .maybeSingle();
  if (exists == null) {
    await _db.from('post_likes').insert({
      'post_id': postId,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // notify post author (if not self) and avoid duplicate notifications
  try {
    final post = await _db
        .from('posts')
        .select('author_id')
        .eq('id', postId)
        .single();
    final receiverId = (post['author_id'] as String?) ?? '';
    if (receiverId.isEmpty || receiverId == userId) return;

    final dup = await _db
        .from('notifications_social')
        .select('id')
        .eq('type', 'like')
        .eq('sender_id', userId)
        .eq('receiver_id', receiverId)
        .eq('post_id', postId)
        .maybeSingle();

    if (dup == null) {
      await _db.from('notifications_social').insert({
        'sender_id': userId,
        'receiver_id': receiverId,
        'type': 'like',
        'post_id': postId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  } catch (_) {}
}


  Future<void> unlikePost({required String postId, required String userId}) async {
    await _db.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
  }

  Future<List<Like>> getLikes(String postId) async {
    final res = await _db.from('post_likes').select().eq('post_id', postId);
    return res.map<Like>((row) {
      return Like(
        id: row['id'],
        postId: row['post_id'],
        userId: row['user_id'],
        createdAt: DateTime.parse(row['created_at']),
      );
    }).toList();
  }

  /// ---------------------------
  /// COMMENTS & REPLIES
  /// ---------------------------

  Future<void> addComment({
  required String postId,
  required String authorId,
  required String content,
}) async {
  await _db.from('comments').insert({
    'post_id': postId,
    'author_id': authorId,
    'content': content,
    'created_at': DateTime.now().toIso8601String(),
  });

  // notify post author
  final post = await _db.from('posts').select('author_id').eq('id', postId).single();
  final receiverId = post['author_id'] as String;
  if (receiverId != authorId) {
    await _db.from('notifications_social').insert({
      'type': 'comment',
      'sender_id': authorId,
      'receiver_id': receiverId,
      'post_id': postId,
    });
  }
}

Future<void> addReply({
  required String postId,
  required String parentCommentId,
  required String authorId,
  required String content,
}) async {
  await _db.from('comments').insert({
    'post_id': postId,
    'parent_comment_id': parentCommentId,
    'author_id': authorId,
    'content': content,
    'created_at': DateTime.now().toIso8601String(),
  });

  // notify post author
  final post = await _db.from('posts').select('author_id').eq('id', postId).single();
  final postAuthorId = post['author_id'] as String;
  if (postAuthorId != authorId) {
    await _db.from('notifications_social').insert({
      'type': 'comment',
      'sender_id': authorId,
      'receiver_id': postAuthorId,
      'post_id': postId,
    });
  }

  // notify parent comment author (if different)
  final parent = await _db.from('comments').select('author_id').eq('id', parentCommentId).single();
  final parentAuthorId = parent['author_id'] as String;
  if (parentAuthorId != authorId && parentAuthorId != postAuthorId) {
    await _db.from('notifications_social').insert({
      'type': 'reply',
      'sender_id': authorId,
      'receiver_id': parentAuthorId,
      'post_id': postId,
    });
  }
}


  Future<List<Comment>> getComments(String postId) async {
    final res = await _db
        .from('comments')
        .select()
        .eq('post_id', postId)
        .isFilter('parent_comment_id', null)
        .order('created_at', ascending: true);

    return res.map<Comment>((row) {
      return Comment(
        id: row['id'],
        postId: row['post_id'],
        authorId: row['author_id'],
        content: row['content'] ?? '',
        createdAt: DateTime.parse(row['created_at']),
        parentCommentId: row['parent_comment_id'],
      );
    }).toList();
  }

  Future<List<Comment>> getReplies(String parentId) async {
    final res = await _db
        .from('comments')
        .select()
        .eq('parent_comment_id', parentId)
        .order('created_at', ascending: true);
    return res.map<Comment>((row) {
      return Comment(
        id: row['id'],
        postId: row['post_id'],
        authorId: row['author_id'],
        content: row['content'] ?? '',
        createdAt: DateTime.parse(row['created_at']),
        parentCommentId: row['parent_comment_id'],
      );
    }).toList();
  }

  Future<void> updateComment(Comment comment) async {
    await _db.from('comments').update({'content': comment.content}).eq('id', comment.id);
  }

  Future<void> deleteComment(String commentId) async {
    // Delete replies first to prevent foreign key issues
    await _db.from('comments').delete().eq('parent_comment_id', commentId);
    await _db.from('comment_likes').delete().eq('comment_id', commentId);
    await _db.from('comments').delete().eq('id', commentId);
  }

  /// ---------------------------
  /// COMMENT LIKES
  /// ---------------------------

  Future<void> likeComment({required String commentId, required String userId}) async {
    await _db.from('comment_likes').insert({
      'comment_id': commentId,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unlikeComment({required String commentId, required String userId}) async {
    await _db.from('comment_likes').delete().eq('comment_id', commentId).eq('user_id', userId);
  }

  Future<List<CommentLike>> getCommentLikes(String commentId) async {
    final res = await _db.from('comment_likes').select().eq('comment_id', commentId);
    return res.map<CommentLike>((row) {
      return CommentLike(
        id: row['id'],
        commentId: row['comment_id'],
        userId: row['user_id'],
        createdAt: DateTime.parse(row['created_at']),
      );
    }).toList();
  }

  /// ---------------------------
  /// HASHTAGS
  /// ---------------------------

  Future<List<String>> getTopHashtags({int limit = 10}) async {
    final res = await _db
        .from('hashtags')
        .select('name, usage_count, last_used_at')
        .order('last_used_at', ascending: false)
        .order('usage_count', ascending: false)
        .limit(limit);
    return res.map<String>((row) => row['name'] as String).toList();
  }

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ]+)');
    return [for (final m in regex.allMatches(text)) m.group(1)!.toLowerCase()];
  }

  List<String> _extractMentions(String text) {
    final regex = RegExp(r'@([A-Za-z0-9_ğüşöçıİĞÜŞÖÇ.]+)');
    return [for (final m in regex.allMatches(text)) m.group(1)!.toLowerCase()];
  }

  /// ---------------------------
  /// REPORTS
  /// ---------------------------

  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    await _db.from('post_reports').insert({
      'post_id': postId,
      'reporter_id': reporterId,
      'reason': reason,
      'details': details ?? '',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// ---------------------------
  /// FRIENDS
  /// ---------------------------

  Future<List<String>> listFriendIds(String meId) async {
    final res = await _db
        .from('friendships')
        .select()
        .or('requester_id.eq.$meId,addressee_id.eq.$meId')
        .eq('status', 'accepted');

    final ids = <String>[];
    for (final row in res) {
      if (row['requester_id'] != meId) ids.add(row['requester_id']);
      if (row['addressee_id'] != meId) ids.add(row['addressee_id']);
    }
    return ids;
  }
}
