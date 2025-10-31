import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_lifecycle_service.dart';
import '../services/chat_service.dart';

/// Global service that listens to ALL chat messages across the app
/// Shows in-app notifications when app is in foreground (regardless of current screen)
class GlobalChatNotificationService {
  static final GlobalChatNotificationService _instance = 
      GlobalChatNotificationService._internal();
  factory GlobalChatNotificationService() => _instance;
  GlobalChatNotificationService._internal();

  final _supa = Supabase.instance.client;
  final _chatService = ChatService();
  RealtimeChannel? _messageChannel;
  bool _isInitialized = false;
  
  // Cache for user display info
  final Map<String, Map<String, dynamic>> _userCache = {};
  
  // Track which conversation user is currently viewing (to avoid duplicate notifications)
  String? _currentConversationId;

  /// Initialize the global listener (call once in main.dart after Supabase init)
  void initialize() {
    if (_isInitialized) {
      print('⚠️ GlobalChatNotificationService already initialized');
      return;
    }
    
    final currentUserId = _supa.auth.currentUser?.id;
    if (currentUserId == null) {
      print('⚠️ Cannot initialize GlobalChatNotificationService - no user logged in');
      return;
    }

    print('🌍 Initializing GlobalChatNotificationService for user: $currentUserId');
    
    try {
      // Subscribe to all message insertions
      _messageChannel = _supa.channel('global-chat-notifications-$currentUserId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('🔔 Realtime message insert detected');
            _handleNewMessage(payload, currentUserId);
          },
        )
        ..subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('✅ GlobalChatNotificationService subscribed to messages');
          } else if (status == RealtimeSubscribeStatus.closed) {
            print('❌ GlobalChatNotificationService subscription closed');
          } else if (error != null) {
            print('❌ GlobalChatNotificationService subscription error: $error');
          }
        });
      
      _isInitialized = true;
      print('✅ GlobalChatNotificationService initialized');
    } catch (e) {
      print('❌ Error initializing GlobalChatNotificationService: $e');
    }
  }

  /// Set the current conversation being viewed (to avoid showing notification for it)
  void setCurrentConversation(String? conversationId) {
    _currentConversationId = conversationId;
    print('📍 Current conversation set to: $conversationId');
  }

  /// Clean up
  void dispose() {
    _messageChannel?.unsubscribe();
    _isInitialized = false;
  }

  Future<void> _handleNewMessage(
    PostgresChangePayload payload,
    String currentUserId,
  ) async {
    try {
      final message = ChatMessage.fromJson(payload.newRecord);
      
      print('💬 Global message received:');
      print('   - from: ${message.senderId}');
      print('   - conversation: ${message.conversationId}');
      print('   - current user: $currentUserId');
      
      // Don't show notification for own messages
      if (message.senderId == currentUserId) {
        print('🚫 Skipping notification - message from self');
        return;
      }
      
      // Don't show notification if user is viewing this conversation
      if (message.conversationId == _currentConversationId) {
        print('🚫 Skipping notification - user is viewing this conversation');
        return;
      }
      
      // Only show in-app notification if app is in foreground
      if (!AppLifecycleService().isInForeground) {
        print('🚫 Skipping in-app notification - app is in background');
        return;
      }
      
      print('📢 Showing in-app notification for global message');
      
      // Get sender info
      final senderInfo = await _getSenderInfo(message.senderId);
      final senderName = senderInfo['name'] ?? 'Someone';
      final senderAvatar = senderInfo['avatar'];
      
      // Decrypt message for preview
      String messagePreview = '(encrypted message)';
      try {
        messagePreview = await _chatService.decryptMessageForUi(message);
        if (messagePreview.length > 50) {
          messagePreview = '${messagePreview.substring(0, 50)}...';
        }
      } catch (e) {
        print('⚠️ Failed to decrypt message: $e');
      }
      
      // Show in-app notification
      showInAppNotification(
        title: senderName,
        message: messagePreview,
        avatarUrl: senderAvatar,
        onTap: () {
          // Note: Navigation handled by the app's navigation system
          // The notification data includes conversation_id for routing
          print('🔔 In-app notification tapped for conversation: ${message.conversationId}');
        },
      );
      
    } catch (e) {
      print('❌ Error handling global message notification: $e');
    }
  }

  Future<Map<String, dynamic>> _getSenderInfo(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    
    try {
      final profile = await _supa
          .from('profiles')
          .select('name, surname, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      
      if (profile != null) {
        final firstName = (profile['name'] as String? ?? '').trim();
        final lastName = (profile['surname'] as String? ?? '').trim();
        final fullName = '$firstName $lastName'.trim();
        
        final info = {
          'name': fullName.isNotEmpty ? fullName : 'Someone',
          'avatar': profile['avatar_url'] as String?,
        };
        
        _userCache[userId] = info;
        return info;
      }
    } catch (e) {
      print('⚠️ Failed to fetch sender info: $e');
    }
    
    return {'name': 'Someone', 'avatar': null};
  }
}
