// lib/services/social_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_user.dart';
import '../models/social_models.dart';

abstract class SocialRepository {
  Future<SocialUser> upsertUser(SocialUser user);
  Future<SocialUser?> getUser(String userId);
  Future<List<SocialUser>> getUsersByIds(List<String> userIds);
  /// Notifications
Future<List<Map<String, dynamic>>> getNotifications(String userId);
Future<void> markNotificationRead(String id);


  Future<List<Post>> listExplore();
  Future<List<Post>> listFriendsFeed(String meId);

  Future<Post> createPost({
    required String authorId,
    required String content,
    required List<String> imagePaths,
  });
  Future<void> updatePost(Post post);
  Future<void> deletePost(String postId);

  Future<void> deleteComment(String commentId);

  Future<void> likePost({required String postId, required String userId});
  Future<void> unlikePost({required String postId, required String userId});
  Future<List<Like>> getLikes(String postId);

  Future<Comment> addComment({
    required String postId,
    required String authorId,
    required String content,
  });
  Future<List<Comment>> getComments(String postId);

  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String authorId,
    required String content,
  });
  Future<List<Comment>> getReplies(String parentCommentId);

  Future<List<SocialUser>> suggestUsers(String query);

  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  });
  Future<void> respondFriendRequest({
    required String requestId,
    required bool accept,
  });
  Future<List<String>> listFriendIds(String meId);

  Future<void> likeComment({
    required String commentId,
    required String userId,
  });
  Future<void> unlikeComment({
    required String commentId,
    required String userId,
  });
  Future<List<CommentLike>> getCommentLikes(String commentId);

  Future<void> updateComment(Comment comment);

  Future<void> clearAllData(); // no-op for Supabase (kept for interface parity)
}

class SupabaseSocialRepository implements SocialRepository {
  SupabaseClient get _supa => Supabase.instance.client;

  // --- USERS ---------------------------------------------------------------

  @override
  Future<SocialUser> upsertUser(SocialUser user) async {
    // Best-effort profile update for display name / avatar
    // If your RLS disallows this, we simply ignore errors.
    try {
      await _supa.from('profiles').update({
        if (user.displayName.isNotEmpty) 'display_name': user.displayName,
        if (user.avatarUrl != null) 'avatar_url': user.avatarUrl,
      }).eq('id', user.id);
    } catch (_) {
      // ignore
    }
    return user;
  }

// inside class SupabaseSocialRepository implements SocialRepository { ... }

@override
Future<SocialUser?> getUser(String userId) async {
  final supa = Supabase.instance.client;
  final row = await supa
      .from('profiles')
      .select('id, name, surname, display_name, avatar_url')
      .eq('id', userId)
      .maybeSingle();

  if (row == null) return null;

  final m = Map<String, dynamic>.from(row);
  return SocialUser(
    id: m['id'] as String,
    displayName: _bestDisplayName(m),
    avatarUrl: (m['avatar_url'] ?? '').toString(),
  );
}


String _bestDisplayName(Map<String, dynamic> m) {
  final dn = (m['display_name'] ?? '').toString().trim();
  if (dn.isNotEmpty) return dn;

  final name = (m['name'] ?? '').toString().trim();
  final surname = (m['surname'] ?? '').toString().trim();
  final full = [name, surname].where((s) => s.isNotEmpty).join(' ').trim();
  return full.isNotEmpty ? full : 'User';
}
 
@override
@override
Future<List<SocialUser>> getUsersByIds(List<String> userIds) async {
  if (userIds.isEmpty) return [];

  final supa = Supabase.instance.client;
  final rows = await supa
      .from('profiles')
      .select('id, name, surname, display_name, avatar_url')
      .inFilter('id', userIds);

  final list = <SocialUser>[];
  for (final r in (rows as List)) {
    final m = Map<String, dynamic>.from(r as Map);
    final display = _bestDisplayName(m);
    list.add(SocialUser(
      id: m['id'] as String,
      displayName: display,
      avatarUrl: (m['avatar_url'] ?? '').toString(),
    ));
  }
  return list;
}


  // --- FEEDS / POSTS -------------------------------------------------------

  @override
Future<List<Post>> listExplore() async {
  final supa = Supabase.instance.client;
  final meId = supa.auth.currentUser?.id;

  // Step 1: Collect friend IDs
  final friendIds = <String>{};
  if (meId != null && meId.isNotEmpty) {
    final fs = await supa
        .from('friendships')
        .select('requester_id, addressee_id, status')
        .or('requester_id.eq.$meId,addressee_id.eq.$meId')
        .eq('status', 'accepted');

    for (final f in (fs as List)) {
      final mm = Map<String, dynamic>.from(f as Map);
      final r = (mm['requester_id'] ?? '').toString();
      final a = (mm['addressee_id'] ?? '').toString();
      if (r != meId && r.isNotEmpty) friendIds.add(r);
      if (a != meId && a.isNotEmpty) friendIds.add(a);
    }
  }

  // Step 2: Fetch posts (limit optional for performance)
  final rows = await supa
      .from('posts')
      .select('id, author_id, content, image_paths, created_at')
      .order('created_at', ascending: false)
      .limit(200);

  // Step 3: Filter out me & friends locally
  final exclude = <String>{if (meId != null) meId, ...friendIds};
  final filtered = (rows as List)
      .where((r) => !exclude.contains(r['author_id']))
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  // Step 4: Map to Post model
  return filtered.map<Post>((m) {
    return Post(
      id: m['id'] as String,
      authorId: m['author_id'] as String,
      content: (m['content'] ?? '').toString(),
      imagePaths: (m['image_paths'] as List?)?.cast<String>() ?? const <String>[],
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
}


  @override
Future<List<Post>> listFriendsFeed(String meId) async {
  final supa = Supabase.instance.client;

  // friend ids (accepted, both directions)
  final fs = await supa
      .from('friendships')
      .select('requester_id, addressee_id, status')
      .or('requester_id.eq.$meId,addressee_id.eq.$meId')
      .eq('status', 'accepted');

  final friendIds = <String>{};
  for (final f in (fs as List)) {
    final mm = Map<String, dynamic>.from(f as Map);
    final r = (mm['requester_id'] ?? '').toString();
    final a = (mm['addressee_id'] ?? '').toString();
    if (r != meId && r.isNotEmpty) friendIds.add(r);
    if (a != meId && a.isNotEmpty) friendIds.add(a);
  }
  if (friendIds.isEmpty) return [];

  final posts = await supa
      .from('posts')
      .select('id, author_id, content, image_paths, created_at')
      .inFilter('author_id', friendIds.toList())
      .order('created_at', ascending: false);

  return (posts as List).map<Post>((r) {
    final m = Map<String, dynamic>.from(r as Map);
    return Post(
      id: m['id'] as String,
      authorId: m['author_id'] as String,
      content: (m['content'] ?? '').toString(),
      imagePaths: (m['image_paths'] as List?)?.cast<String>() ?? const <String>[],
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
}


  @override
  Future<Post> createPost({
    required String authorId,
    required String content,
    required List<String> imagePaths,
  }) async {
    final row = await _supa
        .from('posts')
        .insert({
          'author_id': authorId,
          'content': content.trim(),
          'image_paths': imagePaths,
        })
        .select('id, author_id, content, image_paths, created_at')
        .single();

    final m = Map<String, dynamic>.from(row as Map);
    return Post(
      id: m['id'] as String,
      authorId: m['author_id'] as String,
      content: (m['content'] ?? '').toString(),
      imagePaths: (m['image_paths'] as List?)?.cast<String>() ?? const <String>[],
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  @override
  Future<void> updatePost(Post post) async {
    await _supa
        .from('posts')
        .update({
          'content': post.content,
          'image_paths': post.imagePaths,
        })
        .eq('id', post.id);
  }

  @override
  Future<void> deletePost(String postId) async {
    // also clean up likes and comments if not on cascade
    await _supa.from('post_likes').delete().eq('post_id', postId);
    final comments = await _supa.from('comments').select('id').eq('post_id', postId);
    for (final r in (comments as List)) {
      final cid = r['id'] as String;
      await _supa.from('comment_likes').delete().eq('comment_id', cid);
    }
    await _supa.from('comments').delete().eq('post_id', postId);
    await _supa.from('posts').delete().eq('id', postId);
  }

  // --- COMMENTS ------------------------------------------------------------

  @override
  Future<void> deleteComment(String commentId) async {
    // delete replies first, then likes, then the comment
    final replies =
        await _supa.from('comments').select('id').eq('parent_comment_id', commentId);
    for (final r in (replies as List)) {
      final rid = r['id'] as String;
      await _supa.from('comment_likes').delete().eq('comment_id', rid);
      await _supa.from('comments').delete().eq('id', rid);
    }
    await _supa.from('comment_likes').delete().eq('comment_id', commentId);
    await _supa.from('comments').delete().eq('id', commentId);
  }

  @override
  Future<List<Like>> getLikes(String postId) async {
    final rows =
        await _supa.from('post_likes').select('id, post_id, user_id, created_at').eq('post_id', postId);
    return (rows as List).map<Like>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return Like(
        id: m['id'] as String,
        postId: m['post_id'] as String,
        userId: m['user_id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
  }

  @override
  Future<Comment> addComment({
    required String postId,
    required String authorId,
    required String content,
  }) async {
    final row = await _supa
        .from('comments')
        .insert({
          'post_id': postId,
          'author_id': authorId,
          'content': content.trim(),
          'parent_comment_id': null,
        })
        .select('id, post_id, author_id, content, created_at, parent_comment_id')
        .single();

    final m = Map<String, dynamic>.from(row as Map);
    return Comment(
      id: m['id'] as String,
      postId: m['post_id'] as String,
      authorId: m['author_id'] as String,
      content: (m['content'] ?? '').toString(),
      createdAt: DateTime.parse(m['created_at'] as String),
      parentCommentId: m['parent_comment_id'] as String?,
    );
  }

  @override
  Future<List<Comment>> getComments(String postId) async {
    final rows = await _supa
        .from('comments')
        .select('id, post_id, author_id, content, created_at, parent_comment_id')
        .eq('post_id', postId)
        .isFilter('parent_comment_id', null)
        .order('created_at', ascending: true);

    return (rows as List).map<Comment>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return Comment(
        id: m['id'] as String,
        postId: m['post_id'] as String,
        authorId: m['author_id'] as String,
        content: (m['content'] ?? '').toString(),
        createdAt: DateTime.parse(m['created_at'] as String),
        parentCommentId: m['parent_comment_id'] as String?,
      );
    }).toList();
  }

  @override
  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String authorId,
    required String content,
  }) async {
    final row = await _supa
        .from('comments')
        .insert({
          'post_id': postId,
          'author_id': authorId,
          'content': content.trim(),
          'parent_comment_id': parentCommentId,
        })
        .select('id, post_id, author_id, content, created_at, parent_comment_id')
        .single();

    final m = Map<String, dynamic>.from(row as Map);
    return Comment(
      id: m['id'] as String,
      postId: m['post_id'] as String,
      authorId: m['author_id'] as String,
      content: (m['content'] ?? '').toString(),
      createdAt: DateTime.parse(m['created_at'] as String),
      parentCommentId: m['parent_comment_id'] as String?,
    );
  }

  @override
  Future<List<Comment>> getReplies(String parentCommentId) async {
    final rows = await _supa
        .from('comments')
        .select('id, post_id, author_id, content, created_at, parent_comment_id')
        .eq('parent_comment_id', parentCommentId)
        .order('created_at', ascending: true);

    return (rows as List).map<Comment>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return Comment(
        id: m['id'] as String,
        postId: m['post_id'] as String,
        authorId: m['author_id'] as String,
        content: (m['content'] ?? '').toString(),
        createdAt: DateTime.parse(m['created_at'] as String),
        parentCommentId: m['parent_comment_id'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> updateComment(Comment comment) async {
    await _supa
        .from('comments')
        .update({'content': comment.content})
        .eq('id', comment.id);
  }

  // --- FRIENDS -------------------------------------------------------------

  @override
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    // prevent duplicates
    final existing = await _supa
        .from('friendships')
        .select('id')
        .or('and(requester_id.eq.$fromUserId,addressee_id.eq.$toUserId),and(requester_id.eq.$toUserId,addressee_id.eq.$fromUserId)')
        .maybeSingle();

    if (existing != null) return;

    await _supa.from('friendships').insert({
      'requester_id': fromUserId,
      'addressee_id': toUserId,
      'status': 'pending',
    });
    await createNotification(
      senderId: fromUserId,
      receiverId: toUserId,
      type: 'friend_request',
);

  }

  @override
  Future<void> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    await _supa
        .from('friendships')
        .update({'status': accept ? 'accepted' : 'rejected'})
        .eq('id', requestId);
  }

  @override
  Future<List<String>> listFriendIds(String meId) async {
    final req = await _supa
        .from('friendships')
        .select('addressee_id')
        .eq('requester_id', meId)
        .eq('status', 'accepted');

    final add = await _supa
        .from('friendships')
        .select('requester_id')
        .eq('addressee_id', meId)
        .eq('status', 'accepted');

    return <String>[
      for (final r in (req as List)) (r['addressee_id'] as String),
      for (final r in (add as List)) (r['requester_id'] as String),
    ];
  }


  // --- REACTIONS (POST / COMMENT) -----------------------------------------

  @override
  Future<void> likePost({required String postId, required String userId}) async {
    // ignore conflict duplicates
    final exists = await _supa
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    if (exists != null) return;

    await _supa.from('post_likes').insert({
      'post_id': postId,
      'user_id': userId,
    });
  }

  @override
  Future<void> unlikePost({required String postId, required String userId}) async {
    await _supa
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  @override
  Future<void> likeComment({
    required String commentId,
    required String userId,
  }) async {
    final exists = await _supa
        .from('comment_likes')
        .select('id')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();
    if (exists != null) return;

    await _supa.from('comment_likes').insert({
      'comment_id': commentId,
      'user_id': userId,
    });
  }

  @override
  Future<void> unlikeComment({
    required String commentId,
    required String userId,
  }) async {
    await _supa
        .from('comment_likes')
        .delete()
        .eq('comment_id', commentId)
        .eq('user_id', userId);
  }

  @override
  Future<List<CommentLike>> getCommentLikes(String commentId) async {
    final rows = await _supa
        .from('comment_likes')
        .select('id, comment_id, user_id, created_at')
        .eq('comment_id', commentId);
    return (rows as List).map<CommentLike>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return CommentLike(
        id: m['id'] as String,
        commentId: m['comment_id'] as String,
        userId: m['user_id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
  }

  // --- SEARCH / SUGGEST ----------------------------------------------------

  @override
  Future<List<SocialUser>> suggestUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <SocialUser>[];

    // Try multiple fields; you can tailor this for your schema
    final rows = await _supa
        .from('profiles')
        .select('id, name, surname, display_name, full_name, username, avatar_url, email')
        .or('name.ilike.%$q%,surname.ilike.%$q%,display_name.ilike.%$q%,full_name.ilike.%$q%,username.ilike.%$q%')
        .limit(10);

    final list = <SocialUser>[];
    for (final r in (rows as List)) {
      final map = Map<String, dynamic>.from(r as Map);
      final id = map['id'] as String;

      final name = (map['name'] as String?)?.trim();
      final surname = (map['surname'] as String?)?.trim();
      final display = (map['display_name'] as String?)?.trim();
      final full = (map['full_name'] as String?)?.trim();
      final username = (map['username'] as String?)?.trim();
      final email = (map['email'] as String?)?.trim();

      String displayName = 'User';
      if ((name != null && name.isNotEmpty) || (surname != null && surname.isNotEmpty)) {
        displayName = [name, surname].where((s) => s != null && s!.isNotEmpty).join(' ').trim();
      } else if (display != null && display.isNotEmpty) {
        displayName = display;
      } else if (full != null && full.isNotEmpty) {
        displayName = full;
      } else if (username != null && username.isNotEmpty) {
        displayName = username;
      } else if (email != null && email.isNotEmpty) {
        displayName = email.split('@').first;
      }

      final avatar = (map['avatar_url'] as String?);
      list.add(SocialUser(id: id, displayName: displayName, avatarUrl: avatar));
    }
    return list;
  }

  // --- MISC ----------------------------------------------------------------

  @override
  Future<void> clearAllData() async {
    // No-op for Supabase (client cannot truncate server tables safely).
  }

// ======================
// Notifications (notifications_social)
// ======================

@override
Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
  final supa = Supabase.instance.client;
  final rows = await supa
      .from('notifications_social')
      .select('''
        id,
        type,
        sender_id,
        receiver_id,
        post_id,
        comment_id,
        is_read,
        created_at,
        sender:profiles!sender_id(display_name,name,surname, avatar_url)
      ''')
      .eq('receiver_id', userId)
      .order('created_at', ascending: false);

  // Ensure a clean List<Map<String,dynamic>>
  return List<Map<String, dynamic>>.from(rows as List);
}

@override
Future<void> markNotificationRead(String id) async {
  final supa = Supabase.instance.client;
  await supa
      .from('notifications_social')
      .update({'is_read': true})
      .eq('id', id);
}


// Optional: call this where you create likes/comments/friend-requests
Future<void> createNotification({
  required String senderId,
  required String receiverId,
  required String type, // 'friend_request' | 'like' | 'comment'
  String? postId,
}) async {
  final supa = Supabase.instance.client;
  await supa.from('notifications_social').insert({
    'sender_id': senderId,
    'receiver_id': receiverId,
    'type': type,
    if (postId != null) 'post_id': postId,
  });
}



}
