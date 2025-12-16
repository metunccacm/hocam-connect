import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper class for sending push notifications via Supabase Edge Function
class PushNotificationHelper {
  static final _supabase = Supabase.instance.client;

  /// Send a notification to a single user
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      await _supabase.functions.invoke('push-notification', body: {
        'user_id': userId,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
    } catch (e) {
      print('Error sending push notification: $e');
      rethrow;
    }
  }

  /// Send a notification to multiple users
  static Future<void> sendToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      await _supabase.functions.invoke('push-notification', body: {
        'user_ids': userIds,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
    } catch (e) {
      print('Error sending push notifications: $e');
      rethrow;
    }
  }

  // ===== Feature-Specific Notification Helpers =====

  /// Send notification when someone sends a chat message
  static Future<void> notifyNewChatMessage({
    required String recipientUserId,
    required String senderName,
    required String messagePreview,
    required String chatId,
  }) async {
    await sendToUser(
      userId: recipientUserId,
      title: 'New message from $senderName',
      body: messagePreview,
      data: {
        'type': 'chat',
        'chat_id': chatId,
        'screen': '/chat',
      },
    );
  }

  /// Send notification when someone likes a post
  static Future<void> notifySocialLike({
    required String postAuthorId,
    required String likerName,
    required String postId,
  }) async {
    await sendToUser(
      userId: postAuthorId,
      title: 'New like',
      body: '$likerName liked your post',
      data: {
        'type': 'social_like',
        'post_id': postId,
        'screen': '/social',
      },
    );
  }

  /// Send notification when someone comments on a post
  static Future<void> notifySocialComment({
    required String postAuthorId,
    required String commenterName,
    required String commentText,
    required String postId,
  }) async {
    await sendToUser(
      userId: postAuthorId,
      title: 'New comment from $commenterName',
      body: commentText,
      data: {
        'type': 'social_comment',
        'post_id': postId,
        'screen': '/social',
      },
    );
  }

  /// Send notification when someone sends a friend request
  static Future<void> notifyFriendRequest({
    required String recipientUserId,
    required String senderName,
    required String senderId,
  }) async {
    await sendToUser(
      userId: recipientUserId,
      title: 'New friend request',
      body: '$senderName sent you a friend request',
      data: {
        'type': 'friend_request',
        'sender_id': senderId,
        'screen': '/social',
      },
    );
  }

  /// Send notification when someone joins a hitchhike ride
  static Future<void> notifyHitchhikeJoin({
    required String rideOwnerId,
    required String joinerName,
    required String rideId,
  }) async {
    await sendToUser(
      userId: rideOwnerId,
      title: 'Someone joined your ride!',
      body: '$joinerName joined your hitchhike',
      data: {
        'type': 'hitchhike_join',
        'ride_id': rideId,
        'screen': '/hitchike',
      },
    );
  }

  /// Send notification for marketplace item comment
  static Future<void> notifyMarketplaceComment({
    required String itemOwnerId,
    required String commenterName,
    required String commentText,
    required String itemId,
  }) async {
    await sendToUser(
      userId: itemOwnerId,
      title: 'New comment on your item',
      body: '$commenterName: $commentText',
      data: {
        'type': 'marketplace_comment',
        'item_id': itemId,
        'screen': '/marketplace',
      },
    );
  }

  /// Send notification when marketplace item is sold
  static Future<void> notifyMarketplaceSold({
    required String buyerId,
    required String itemName,
    required String itemId,
  }) async {
    await sendToUser(
      userId: buyerId,
      title: 'Item sold!',
      body: '$itemName has been marked as sold',
      data: {
        'type': 'marketplace_sold',
        'item_id': itemId,
        'screen': '/marketplace',
      },
    );
  }
}
