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

    try {
      final requestBody = {
        if (userId != null) 'user_id': userId,
        if (userIds != null && userIds.isNotEmpty) 'user_ids': userIds,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      final response = await _supabase.functions.invoke(
        'push-notification',
        body: requestBody,
      );

      if (response.status != 200) {
        throw Exception('Push notification failed: ${response.data}');
      }
    } catch (e) {
      print('⚠️ Error sending push notification: $e');
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

  /// Get notification history for current user
  /// Only returns broadcast notifications (announcements)
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
}
