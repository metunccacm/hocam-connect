import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper class for sending push notifications
///
/// IMPORTANT:
/// - Use sendBroadcast() for system announcements to all users (stores in DB)
/// - Use sendDirect() for private notifications (chat, social, etc.) - NO database storage
/// - notifications table is ONLY for broadcasts/announcements for security/privacy
class NotificationRepository {
  static final _supabase = Supabase.instance.client;

  /// Send notification directly via Edge Function (NO database storage)
  /// Use for private notifications: chat, social interactions, etc.
  static Future<void> sendDirect({
    String? userId,
    List<String>? userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    if (userId == null && (userIds == null || userIds.isEmpty)) {
      throw ArgumentError('Must provide either userId or userIds');
    }

    print('🚀 sendDirect called with:');
    print('   - userId: $userId');
    print('   - userIds: $userIds');
    print('   - title: $title');
    print('   - body: $body');

    try {
      final requestBody = {
        if (userId != null) 'user_id': userId,
        if (userIds != null && userIds.isNotEmpty) 'user_ids': userIds,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      print('📤 Calling Edge Function with body: $requestBody');

      final response = await _supabase.functions.invoke(
        'push-notification',
        body: requestBody,
      );

      print('📥 Edge Function response:');
      print('   - status: ${response.status}');
      print('   - data: ${response.data}');

      if (response.status == 200) {
        print('✅ Successfully sent direct notification');
      } else {
        print('❌ Push notification failed with status ${response.status}');
        throw Exception('Push notification failed: ${response.data}');
      }
    } catch (e) {
      print('❌ Error sending direct notification: $e');
      rethrow;
    }
  }

  /// Send broadcast notification to all users (stores in notifications table)
  /// Use ONLY for system announcements
  static Future<String> sendBroadcast({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('notify_all_users', params: {
        'p_title': title,
        'p_body': body,
        'p_data': data ?? {},
        'p_notification_type': 'announcement',
        'p_image_url': imageUrl,
      });

      return response as String;
    } catch (e) {
      print('Error broadcasting notification: $e');
      rethrow;
    }
  }

  // ========== DEPRECATED METHODS (kept for backwards compatibility) ==========
  // These methods store in DB - should only be used for announcements
  // Use sendDirect() instead for private notifications

  /// @deprecated Use sendBroadcast() for announcements or sendDirect() for private notifications
  static Future<String> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? notificationType,
    String? referenceId,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('notify_user', params: {
        'p_user_id': userId,
        'p_title': title,
        'p_body': body,
        'p_data': data ?? {},
        'p_notification_type': notificationType,
        'p_reference_id': referenceId,
        'p_image_url': imageUrl,
      });

      return response as String;
    } catch (e) {
      print('Error sending notification: $e');
      rethrow;
    }
  }

  /// @deprecated Use sendBroadcast() for announcements or sendDirect() for private notifications
  static Future<String> sendToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? notificationType,
    String? referenceId,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('notify_users', params: {
        'p_user_ids': userIds,
        'p_title': title,
        'p_body': body,
        'p_data': data ?? {},
        'p_notification_type': notificationType,
        'p_reference_id': referenceId,
        'p_image_url': imageUrl,
      });

      return response as String;
    } catch (e) {
      print('Error sending notifications: $e');
      rethrow;
    }
  }

  /// @deprecated Use sendBroadcast() instead
  static Future<String> sendToAllUsers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? notificationType,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('notify_all_users', params: {
        'p_title': title,
        'p_body': body,
        'p_data': data ?? {},
        'p_notification_type': notificationType,
        'p_image_url': imageUrl,
      });

      return response as String;
    } catch (e) {
      print('Error broadcasting notification: $e');
      rethrow;
    }
  }

  /// Get notification history for current user
  static Future<List<Map<String, dynamic>>> getUserNotifications({
    int limit = 50,
    String? notificationType,
  }) async {
    try {
      var queryBuilder = _supabase.from('notifications').select().or(
          'user_id.eq.${_supabase.auth.currentUser!.id},sender_id.eq.${_supabase.auth.currentUser!.id}');

      if (notificationType != null) {
        queryBuilder = queryBuilder.eq('notification_type', notificationType);
      }

      final response =
          await queryBuilder.order('created_at', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching notifications: $e');
      rethrow;
    }
  }

  /// Get notification status
  static Future<Map<String, dynamic>?> getNotificationStatus(
      String notificationId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('id', notificationId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching notification status: $e');
      return null;
    }
  }

  // ===== Feature-Specific Helpers =====

  /// Notify when new chat message
  static Future<String> notifyChatMessage({
    required String recipientUserId,
    required String senderName,
    required String messagePreview,
    required String chatId,
  }) async {
    return await sendToUser(
      userId: recipientUserId,
      title: 'New message from $senderName',
      body: messagePreview,
      data: {
        'type': 'chat',
        'chat_id': chatId,
        'screen': '/chat',
      },
      notificationType: 'chat',
      referenceId: chatId,
    );
  }

  /// Notify when someone likes a post
  static Future<String> notifySocialLike({
    required String postAuthorId,
    required String likerName,
    required String postId,
  }) async {
    return await sendToUser(
      userId: postAuthorId,
      title: 'New like',
      body: '$likerName liked your post',
      data: {
        'type': 'social_like',
        'post_id': postId,
        'screen': '/social',
      },
      notificationType: 'social_like',
      referenceId: postId,
    );
  }

  /// Notify when someone comments on a post
  static Future<String> notifySocialComment({
    required String postAuthorId,
    required String commenterName,
    required String commentText,
    required String postId,
  }) async {
    return await sendToUser(
      userId: postAuthorId,
      title: 'New comment from $commenterName',
      body: commentText.length > 100
          ? '${commentText.substring(0, 100)}...'
          : commentText,
      data: {
        'type': 'social_comment',
        'post_id': postId,
        'screen': '/social',
      },
      notificationType: 'social_comment',
      referenceId: postId,
    );
  }

  /// Notify when friend request received
  static Future<String> notifyFriendRequest({
    required String recipientUserId,
    required String senderName,
    required String senderId,
  }) async {
    return await sendToUser(
      userId: recipientUserId,
      title: 'New friend request',
      body: '$senderName sent you a friend request',
      data: {
        'type': 'friend_request',
        'sender_id': senderId,
        'screen': '/social',
      },
      notificationType: 'friend_request',
      referenceId: senderId,
    );
  }

  /// Notify when someone joins hitchhike ride
  static Future<String> notifyHitchhikeJoin({
    required String rideOwnerId,
    required String joinerName,
    required String rideId,
  }) async {
    return await sendToUser(
      userId: rideOwnerId,
      title: 'Someone joined your ride!',
      body: '$joinerName joined your hitchhike',
      data: {
        'type': 'hitchhike_join',
        'ride_id': rideId,
        'screen': '/hitchike',
      },
      notificationType: 'hitchhike_join',
      referenceId: rideId,
    );
  }

  /// Notify when marketplace item gets a comment
  static Future<String> notifyMarketplaceComment({
    required String itemOwnerId,
    required String commenterName,
    required String commentText,
    required String itemId,
  }) async {
    return await sendToUser(
      userId: itemOwnerId,
      title: 'New comment on your item',
      body:
          '$commenterName: ${commentText.length > 80 ? '${commentText.substring(0, 80)}...' : commentText}',
      data: {
        'type': 'marketplace_comment',
        'item_id': itemId,
        'screen': '/marketplace',
      },
      notificationType: 'marketplace_comment',
      referenceId: itemId,
    );
  }

  /// Notify when item is sold
  static Future<String> notifyMarketplaceSold({
    required String buyerId,
    required String itemName,
    required String itemId,
  }) async {
    return await sendToUser(
      userId: buyerId,
      title: 'Item sold!',
      body: '$itemName has been marked as sold',
      data: {
        'type': 'marketplace_sold',
        'item_id': itemId,
        'screen': '/marketplace',
      },
      notificationType: 'marketplace_sold',
      referenceId: itemId,
    );
  }

  /// Send announcement to all users
  static Future<String> sendAnnouncement({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    return await sendToAllUsers(
      title: title,
      body: body,
      data: {'type': 'announcement'},
      notificationType: 'announcement',
      imageUrl: imageUrl,
    );
  }
}
