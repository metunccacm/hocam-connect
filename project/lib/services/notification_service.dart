import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_service.dart';

/// Background message handler (must be top-level function)
/// This decrypts messages when app is in background/terminated
/// Similar to how WhatsApp shows actual message content in notifications
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('🌙 Background message received: ${message.messageId}');
    print('   Data: ${message.data}');
  }
  
  try {
    // Initialize Firebase if needed
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    
    // Check if Supabase is available
    // Note: Supabase should be initialized in main.dart before this runs
    try {
      final _ = Supabase.instance.client.auth.currentUser;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Supabase not available in background handler: $e');
      }
      return;
    }
    
    // Check if it's a chat message
    final type = message.data['type'] as String?;
    final messageId = message.data['message_id'] as String?;
    final senderName = message.data['sender_name'] as String?;
    
    if (type == 'chat' && messageId != null) {
      if (kDebugMode) {
        print('💬 Chat message detected in background');
      }
      
      // Import ChatService and decrypt
      // Note: This requires the user's E2EE keys to be available
      try {
        final chatService = ChatService();
        await chatService.ensureMyLongTermKey();
        
        // Fetch the message from database
        final messageData = await Supabase.instance.client
            .from('messages')
            .select()
            .eq('id', messageId)
            .single();
        
        final chatMessage = ChatMessage.fromJson(messageData);
        
        // Decrypt the message
        final decryptedText = await chatService.decryptMessageForUi(chatMessage);
        
        // Show local notification with decrypted content
        final localNotifications = FlutterLocalNotificationsPlugin();
        
        // Initialize local notifications
        await localNotifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        
        // Show notification with actual message content
        await localNotifications.show(
          message.hashCode,
          senderName ?? 'New Message',
          decryptedText.length > 100 
              ? '${decryptedText.substring(0, 100)}...' 
              : decryptedText,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_messages',
              'Chat Messages',
              channelDescription: 'Notifications for new chat messages',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );
        
        if (kDebugMode) {
          print('✅ Background notification shown with decrypted content');
        }
        
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to decrypt message in background: $e');
          print('   Showing generic notification instead');
        }
        
        // Fallback: Show generic notification if decryption fails
        final localNotifications = FlutterLocalNotificationsPlugin();
        await localNotifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        
        await localNotifications.show(
          message.hashCode,
          senderName ?? 'New Message',
          'Sent you a message',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_messages',
              'Chat Messages',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error in background message handler: $e');
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _notificationEnabledKey = 'notifications_enabled';
  static const String _fcmTokenKey = 'fcm_token';

  String? _currentToken;
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Firebase not initialized. Skipping notification service setup.');
          print('📝 Add Firebase configuration files to enable push notifications.');
        }
        return;
      }
      
      if (kDebugMode) {
        print('🚀 Starting notification service initialization...');
        print('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      }
      
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permission
      if (kDebugMode) {
        print('🔔 Requesting notification permissions...');
      }
      final notificationSettings = await _requestPermission();
      
      if (kDebugMode) {
        print('🔔 Permission status: ${notificationSettings.authorizationStatus}');
      }

      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('✅ Notification permission granted, getting FCM token...');
        }
        
        // Get FCM token
        await _getFCMToken();

        // Setup foreground notification handling
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Setup notification tap handling
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Handle notification that opened the app from terminated state
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

        _isInitialized = true;
        if (kDebugMode) {
          print('NotificationService initialized successfully');
        }
      } else {
        if (kDebugMode) {
          print('Notification permission not granted');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notification service: $e');
      }
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Request notification permission
  Future<NotificationSettings> _requestPermission() async {
    return await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  /// Get FCM token and save it
  Future<void> _getFCMToken() async {
    try {
      if (kDebugMode) {
        print('🔑 _getFCMToken() called');
      }
      
      // For iOS, we need to wait for APNS token first
      if (Platform.isIOS) {
        if (kDebugMode) {
          print('🍎 iOS detected - checking for APNS token...');
        }
        
        // Try multiple times with increasing delays
        String? apnsToken;
        for (int i = 0; i < 3; i++) {
          if (kDebugMode) {
            print('🔍 Attempt ${i + 1}/3: Calling getAPNSToken()...');
          }
          
          try {
            apnsToken = await _firebaseMessaging.getAPNSToken();
            if (kDebugMode) {
              if (apnsToken != null) {
                print('✅ APNS token received on attempt ${i + 1}: ${apnsToken.substring(0, min(20, apnsToken.length))}...');
              } else {
                print('❌ APNS token is null on attempt ${i + 1}');
              }
            }
            if (apnsToken != null) break;
          } catch (e) {
            if (kDebugMode) {
              print('❌ Error getting APNS token on attempt ${i + 1}: $e');
            }
          }
          
          if (apnsToken == null && i < 2) {
            if (kDebugMode) {
              print('⏳ Waiting ${2 + i} seconds before retry...');
            }
            await Future.delayed(Duration(seconds: 2 + i)); // 2s, 3s, 4s
          }
        }
        
        if (apnsToken == null) {
          if (kDebugMode) {
            print('⚠️ APNS token not available after 3 attempts. Will retry in background...');
            print('💡 Make sure:');
            print('   1. You\'re testing on a REAL iOS device (not simulator)');
            print('   2. Push Notifications capability is enabled in Xcode');
            print('   3. APNs is configured in Firebase Console');
            print('   4. Runner.entitlements has aps-environment key');
          }
          // Set up background retry mechanism
          _setupAPNSTokenListener();
          return;
        }
        
        if (kDebugMode) {
          print('✅ APNS token available: ${apnsToken.substring(0, min(20, apnsToken.length))}...');
        }
      }
      
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _saveTokenLocally(token);
        
        // Save token to Supabase if user is logged in
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await _saveTokenToSupabase(token, user.id);
        }
        
        if (kDebugMode) {
          print('FCM Token: $token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }
  }

  /// Setup listener for APNS token on iOS
  void _setupAPNSTokenListener() {
    if (Platform.isIOS) {
      _retryGetFCMToken(attempts: 0, maxAttempts: 5);
    }
  }

  /// Retry getting FCM token with exponential backoff
  Future<void> _retryGetFCMToken({required int attempts, required int maxAttempts}) async {
    if (attempts >= maxAttempts) {
      if (kDebugMode) {
        print('⚠️ Max attempts reached. FCM token will be retrieved on next app launch.');
      }
      return;
    }

    // Exponential backoff: 3s, 5s, 10s, 15s, 20s
    final delays = [3, 5, 10, 15, 20];
    final delay = delays[attempts < delays.length ? attempts : delays.length - 1];

    await Future.delayed(Duration(seconds: delay));

    try {
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      if (apnsToken != null) {
        if (kDebugMode) {
          print('✅ APNS token now available (attempt ${attempts + 1}), getting FCM token...');
        }
        
        // Try to get FCM token
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          _currentToken = token;
          await _saveTokenLocally(token);
          
          // Save token to Supabase if user is logged in
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            await _saveTokenToSupabase(token, user.id);
          }
          
          if (kDebugMode) {
            print('✅ FCM Token retrieved: $token');
          }
          return; // Success!
        }
      } else {
        if (kDebugMode) {
          print('⏳ Still waiting for APNS token (attempt ${attempts + 1}/$maxAttempts)...');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during retry attempt ${attempts + 1}: $e');
      }
    }

    // Retry again
    await _retryGetFCMToken(attempts: attempts + 1, maxAttempts: maxAttempts);
  }

  /// Save token locally
  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
  }

  /// Get locally saved token
  Future<String?> getLocalToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Save token to Supabase profiles table
  Future<void> _saveTokenToSupabase(String token, String userId) async {
    try {
      if (kDebugMode) {
        print('💾 Saving FCM token to profiles table...');
        print('   User ID: $userId');
        print('   Token: ${token.substring(0, min(20, token.length))}...');
        print('   Platform: ${Platform.isIOS ? 'ios' : 'android'}');
      }
      
      await Supabase.instance.client
          .from('profiles')
          .update({
            'fcm_token': token,
            'fcm_platform': Platform.isIOS ? 'ios' : 'android',
          })
          .eq('id', userId);
      
      if (kDebugMode) {
        print('✅ FCM token saved to profiles table successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving FCM token to Supabase profiles: $e');
      }
    }
  }

  /// Delete token from Supabase profiles table
  Future<void> deleteTokenFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'fcm_token': null,
              'fcm_platform': null,
            })
            .eq('id', user.id);
        
        if (kDebugMode) {
          print('✅ FCM token cleared from profiles table');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting FCM token from Supabase: $e');
      }
    }
  }

  /// Save FCM token for currently logged-in user
  /// Call this after user logs in to ensure their token is saved
  Future<void> saveFCMTokenForCurrentUser() async {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Firebase not initialized. Cannot save FCM token.');
        }
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No user logged in, cannot save FCM token');
        }
        return;
      }

      // For iOS, check if APNS token is available
      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          if (kDebugMode) {
            print('⏳ APNS token not available yet. Will retry when available.');
          }
          // Setup retry mechanism
          _setupAPNSTokenListener();
          return;
        }
      }

      // Get current token (from local storage or fetch new one)
      String? token = _currentToken ?? await getLocalToken();
      
      if (token == null) {
        // Try to get fresh token from Firebase
        token = await _firebaseMessaging.getToken();
        if (token != null) {
          _currentToken = token;
          await _saveTokenLocally(token);
        }
      }

      if (token != null) {
        await _saveTokenToSupabase(token, user.id);
        if (kDebugMode) {
          print('✅ FCM token saved for user: ${user.id}');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No FCM token available to save');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token for current user: $e');
      }
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    _currentToken = newToken;
    await _saveTokenLocally(newToken);
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await _saveTokenToSupabase(newToken, user.id);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('🔔 Foreground message received');
      print('   Title: ${message.notification?.title}');
      print('   Body: ${message.notification?.body}');
      print('   Data: ${message.data}');
    }

    // For E2EE chats, we rely on GlobalChatNotificationService for in-app notifications
    // which can decrypt messages. Push notifications are generic ("New message from X")
    
    // Only show local notification if it's not a chat message
    // (chat messages are handled by GlobalChatNotificationService which decrypts them)
    if (message.data['type'] != 'chat') {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    } else {
      if (kDebugMode) {
        print('🚫 Skipping local notification - chat messages handled by GlobalChatNotificationService');
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap (when app was in background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('🔔 Notification tapped');
      print('   Data: ${message.data}');
    }
    
    // Navigate based on notification type
    final type = message.data['type'] as String?;
    final conversationId = message.data['conversation_id'] as String?;
    
    if (type == 'chat' && conversationId != null) {
      // Store navigation intent - will be handled by main app after it fully loads
      _pendingChatNavigation = conversationId;
      if (kDebugMode) {
        print('📍 Pending navigation to conversation: $conversationId');
      }
    }
    
    // TODO: Handle other notification types (social, marketplace, etc.)
  }
  
  // Store pending navigation for handling after app loads
  String? _pendingChatNavigation;
  
  /// Get and clear pending chat navigation
  String? getPendingChatNavigation() {
    final pending = _pendingChatNavigation;
    _pendingChatNavigation = null;
    return pending;
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Local notification tapped: ${response.payload}');
    }
    // TODO: Handle navigation based on payload
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationEnabledKey) ?? true; // Default to true
  }

  /// Enable notifications
  Future<void> enableNotifications() async {
    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Cannot enable notifications: Firebase not initialized');
      }
      throw Exception('Firebase not initialized. Add Firebase configuration files first.');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, true);

    // Re-register FCM token if not initialized
    if (!_isInitialized) {
      await initialize();
    } else if (_currentToken != null) {
      // Re-save token to Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _saveTokenToSupabase(_currentToken!, user.id);
      }
    }
  }

  /// Disable notifications
  Future<void> disableNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, false);

    // Delete token from Supabase
    await deleteTokenFromSupabase();

    // Delete FCM token
    await _firebaseMessaging.deleteToken();
    _currentToken = null;
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Check notification permission status
  Future<bool> hasPermission() async {
    if (Firebase.apps.isEmpty) return false;
    
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Request permission again (for when user manually disabled it)
  Future<bool> requestPermissionAgain() async {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase not initialized. Add Firebase configuration files first.');
    }
    
    final settings = await _requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await initialize();
      return true;
    }
    return false;
  }
}
