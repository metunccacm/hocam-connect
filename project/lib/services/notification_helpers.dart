import 'notification_repository.dart';

/// Convenience methods for sending feature-specific push notifications
/// All notifications are sent directly (no DB storage) for privacy/security
class NotificationHelpers {
  /// Send chat message notification
  static Future<void> notifyNewMessage({
    required List<String> recipientIds,
    required String senderName,
    required String messagePreview,
    required String conversationId,
  }) async {
    if (recipientIds.isEmpty) return;

    await NotificationRepository.sendDirect(
      userIds: recipientIds,
      title: 'New message from $senderName',
      body: messagePreview,
      data: {
        'type': 'chat',
        'conversation_id': conversationId,
        'screen': '/chat',
      },
    );
  }

  /// Send social post like notification
  static Future<void> notifyPostLike({
    required String postAuthorId,
    required String likerName,
    required String postId,
  }) async {
    await NotificationRepository.sendDirect(
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

  /// Send social post comment notification
  static Future<void> notifyPostComment({
    required String postAuthorId,
    required String commenterName,
    required String commentPreview,
    required String postId,
  }) async {
    await NotificationRepository.sendDirect(
      userId: postAuthorId,
      title: 'New comment from $commenterName',
      body: commentPreview.length > 100
          ? '${commentPreview.substring(0, 100)}...'
          : commentPreview,
      data: {
        'type': 'social_comment',
        'post_id': postId,
        'screen': '/social',
      },
    );
  }

  /// Send friend request notification
  static Future<void> notifyFriendRequest({
    required String recipientId,
    required String senderName,
    required String senderId,
  }) async {
    await NotificationRepository.sendDirect(
      userId: recipientId,
      title: 'New friend request',
      body: '$senderName sent you a friend request',
      data: {
        'type': 'friend_request',
        'sender_id': senderId,
        'screen': '/social',
      },
    );
  }

  /// Send hitchhike ride join notification
  static Future<void> notifyRideJoin({
    required String rideOwnerId,
    required String joinerName,
    required String rideId,
  }) async {
    await NotificationRepository.sendDirect(
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

  /// Send marketplace item comment notification
  static Future<void> notifyItemComment({
    required String itemOwnerId,
    required String commenterName,
    required String commentText,
    required String itemId,
  }) async {
    await NotificationRepository.sendDirect(
      userId: itemOwnerId,
      title: 'New comment on your item',
      body:
          '$commenterName: ${commentText.length > 80 ? '${commentText.substring(0, 80)}...' : commentText}',
      data: {
        'type': 'marketplace_comment',
        'item_id': itemId,
        'screen': '/marketplace',
      },
    );
  }

  /// Send marketplace item sold notification
  static Future<void> notifyItemSold({
    required String buyerId,
    required String itemName,
    required String itemId,
  }) async {
    await NotificationRepository.sendDirect(
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

  /// Send system announcement to all users (stores in DB)
  static Future<String> sendAnnouncement({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    return await NotificationRepository.sendBroadcast(
      title: title,
      body: body,
      data: {'type': 'announcement'},
      imageUrl: imageUrl,
    );
  }
}
