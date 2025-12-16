import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler (must be top-level function)
/// Handles push notifications when app is in background or terminated
/// 
/// IMPORTANT: Firebase automatically displays notifications when the app is backgrounded.
/// This handler is ONLY for additional data processing (updating badges, caching, etc.)
/// Do NOT manually show notifications here as it will create duplicates!
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handlers run in their own isolate. Keep logic minimal.
  if (kDebugMode) {
    debugPrint('🌙 Background message received: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
  }

  // Firebase automatically shows the notification.
  // We only need to process data here if needed (e.g., update badge count, cache data)
  
  // TODO: Add any background data processing here if needed
  // Examples:
  // - Update badge count
  // - Cache message data
  // - Update local database
  
  if (kDebugMode) {
    debugPrint('✅ Background message processed (notification shown by Firebase)');
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
  
  // Store navigator key for navigation from notifications
  GlobalKey<NavigatorState>? _navigatorKey;
  
  /// Set the navigator key for navigation from notifications
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '⚠️ Firebase not initialized. Skipping notification service setup.');
          debugPrint(
              '📝 Add Firebase configuration files to enable push notifications.');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('🚀 Starting notification service initialization...');
        debugPrint('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permission
      if (kDebugMode) {
        debugPrint('🔔 Requesting notification permissions...');
      }
      final notificationSettings = await _requestPermission();

      if (kDebugMode) {
        debugPrint(
            '🔔 Permission status: ${notificationSettings.authorizationStatus}');
      }

      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.authorized) {
        if (kDebugMode) {
          debugPrint('✅ Notification permission granted, getting FCM token...');
        }

        // Get FCM token
        await _getFCMToken();

        // NOTE: Background message handler is already registered in main.dart
        // Registering it here would cause duplicate notifications!
        
        // Setup notification tap handling (when app is opened from background/terminated)
        if (kDebugMode) {
          debugPrint('🎯 Setting up onMessageOpenedApp listener...');
        }
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          if (kDebugMode) {
            debugPrint('🔔 onMessageOpenedApp triggered!');
          }
          _handleNotificationTap(message);
        });

        // Handle notification that opened the app from terminated state
        if (kDebugMode) {
          debugPrint('🔍 Checking for initial message (app opened from terminated)...');
        }
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          if (kDebugMode) {
            debugPrint('✅ Found initial message!');
          }
          _handleNotificationTap(initialMessage);
        } else {
          if (kDebugMode) {
            debugPrint('ℹ️ No initial message found');
          }
        }

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

        _isInitialized = true;
        if (kDebugMode) {
          debugPrint('NotificationService initialized successfully');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Notification permission not granted');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing notification service: $e');
      }
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/hc_logo');
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
        debugPrint('🔑 _getFCMToken() called');
      }

      // For iOS, we need to wait for APNS token first
      if (Platform.isIOS) {
        if (kDebugMode) {
          debugPrint('🍎 iOS detected - checking for APNS token...');
        }

        // Try multiple times with increasing delays
        String? apnsToken;
        for (int i = 0; i < 3; i++) {
          if (kDebugMode) {
            debugPrint('🔍 Attempt ${i + 1}/3: Calling getAPNSToken()...');
          }

          try {
            apnsToken = await _firebaseMessaging.getAPNSToken();
            if (kDebugMode) {
              if (apnsToken != null) {
                debugPrint(
                    '✅ APNS token received on attempt ${i + 1}: ${apnsToken.substring(0, min(20, apnsToken.length))}...');
              } else {
                debugPrint('❌ APNS token is null on attempt ${i + 1}');
              }
            }
            if (apnsToken != null) break;
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ Error getting APNS token on attempt ${i + 1}: $e');
            }
          }

          if (apnsToken == null && i < 2) {
            if (kDebugMode) {
              debugPrint('⏳ Waiting ${2 + i} seconds before retry...');
            }
            await Future.delayed(Duration(seconds: 2 + i)); // 2s, 3s, 4s
          }
        }

        if (apnsToken == null) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ APNS token not available after 3 attempts. Will retry in background...');
            debugPrint('💡 Make sure:');
            debugPrint('   1. You\'re testing on a REAL iOS device (not simulator)');
            debugPrint('   2. Push Notifications capability is enabled in Xcode');
            debugPrint('   3. APNs is configured in Firebase Console');
            debugPrint('   4. Runner.entitlements has aps-environment key');
          }
          // Set up background retry mechanism
          _setupAPNSTokenListener();
          return;
        }

        if (kDebugMode) {
          debugPrint(
              '✅ APNS token available: ${apnsToken.substring(0, min(20, apnsToken.length))}...');
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
          debugPrint('FCM Token: $token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting FCM token: $e');
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
  Future<void> _retryGetFCMToken(
      {required int attempts, required int maxAttempts}) async {
    if (attempts >= maxAttempts) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ Max attempts reached. FCM token will be retrieved on next app launch.');
      }
      return;
    }

    // Exponential backoff: 3s, 5s, 10s, 15s, 20s
    final delays = [3, 5, 10, 15, 20];
    final delay =
        delays[attempts < delays.length ? attempts : delays.length - 1];

    await Future.delayed(Duration(seconds: delay));

    try {
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      if (apnsToken != null) {
        if (kDebugMode) {
          debugPrint(
              '✅ APNS token now available (attempt ${attempts + 1}), getting FCM token...');
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
            debugPrint('✅ FCM Token retrieved: $token');
          }
          return; // Success!
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              '⏳ Still waiting for APNS token (attempt ${attempts + 1}/$maxAttempts)...');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during retry attempt ${attempts + 1}: $e');
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
        debugPrint('💾 Saving FCM token to profiles table...');
        debugPrint('   User ID: $userId');
        debugPrint('   Token: ${token.substring(0, min(20, token.length))}...');
        debugPrint('   Platform: ${Platform.isIOS ? 'ios' : 'android'}');
      }

      await Supabase.instance.client.from('profiles').update({
        'fcm_token': token,
        'fcm_platform': Platform.isIOS ? 'ios' : 'android',
      }).eq('id', userId);

      if (kDebugMode) {
        debugPrint('✅ FCM token saved to profiles table successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving FCM token to Supabase profiles: $e');
      }
    }
  }

  /// Delete token from Supabase profiles table
  Future<void> deleteTokenFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').update({
          'fcm_token': null,
          'fcm_platform': null,
        }).eq('id', user.id);

        if (kDebugMode) {
          debugPrint('✅ FCM token cleared from profiles table');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting FCM token from Supabase: $e');
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
          debugPrint('⚠️ Firebase not initialized. Cannot save FCM token.');
        }
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('No user logged in, cannot save FCM token');
        }
        return;
      }

      // For iOS, check if APNS token is available
      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          if (kDebugMode) {
            debugPrint('⏳ APNS token not available yet. Will retry when available.');
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
          debugPrint('✅ FCM token saved for user: ${user.id}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ No FCM token available to save');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving FCM token for current user: $e');
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

  /// Handle notification tap (when app was in background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('🔔 ========== NOTIFICATION TAPPED ==========');
      debugPrint('   Message ID: ${message.messageId}');
      debugPrint('   Notification: ${message.notification?.toMap()}');
      debugPrint('   Data: ${message.data}');
      debugPrint('   Data keys: ${message.data.keys.toList()}');
      debugPrint('   Data values: ${message.data.values.toList()}');
    }

    // Navigate based on notification type
    final type = message.data['type'] as String?;
    final conversationId = message.data['conversation_id'] as String?;

    if (kDebugMode) {
      debugPrint('   Parsed type: $type');
      debugPrint('   Parsed conversation_id: $conversationId');
    }

    if (type == 'chat' && conversationId != null) {
      // Store navigation intent - will be handled by main app after it fully loads
      _pendingChatNavigation = conversationId;
      if (kDebugMode) {
        debugPrint('✅ Pending navigation stored: $conversationId');
        debugPrint('==========================================');
      }
      
      // Try immediate navigation if navigator is available
      _tryImmediateNavigation(conversationId);
    } else {
      if (kDebugMode) {
        debugPrint('❌ Navigation NOT stored - type: $type, conversationId: $conversationId');
        debugPrint('==========================================');
      }
    }

    // TODO: Handle other notification types (social, marketplace, etc.)
  }

  /// Try to navigate immediately if the app is already running
  Future<void> _tryImmediateNavigation(String conversationId) async {
    if (kDebugMode) {
      debugPrint('🚀 Attempting immediate navigation...');
      debugPrint('   Navigator key available: ${_navigatorKey != null}');
      debugPrint('   Current context: ${_navigatorKey?.currentContext != null}');
    }

    // Wait a brief moment for the app to come to foreground
    await Future.delayed(const Duration(milliseconds: 300));

    if (_navigatorKey?.currentContext != null) {
      if (kDebugMode) {
        debugPrint('✅ Navigator context available, navigating now...');
      }

      try {
        // Get conversation details
        final supa = Supabase.instance.client;
        final currentUserId = supa.auth.currentUser?.id;

        if (currentUserId == null) {
          if (kDebugMode) {
            debugPrint('❌ No authenticated user');
          }
          return;
        }

        if (kDebugMode) {
          debugPrint('📊 Fetching chat details for: $conversationId');
        }

        // Get other participant's info
        final participants = await supa
            .from('participants')
            .select('user_id')
            .eq('conversation_id', conversationId)
            .neq('user_id', currentUserId);

        if (participants.isEmpty) {
          if (kDebugMode) {
            debugPrint('❌ No participants found');
          }
          return;
        }

        final otherUserId = participants.first['user_id'] as String;
        if (kDebugMode) {
          debugPrint('👤 Other user ID: $otherUserId');
        }

        // Get other user's profile
        final profile = await supa
            .from('profiles')
            .select('name, surname')
            .eq('id', otherUserId)
            .single();

        final chatTitle = '${profile['name']} ${profile['surname']}';
        if (kDebugMode) {
          debugPrint('💬 Navigating to chat with: $chatTitle');
        }

        // Navigate to ChatView
        // Import dynamically to avoid circular dependency
        _navigatorKey!.currentState?.pushNamed(
          '/chat',
          arguments: {
            'conversationId': conversationId,
            'title': chatTitle,
          },
        );
        
        // Clear pending navigation since we handled it
        _pendingChatNavigation = null;
        
        if (kDebugMode) {
          debugPrint('✅ Navigation completed!');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ Error during immediate navigation: $e');
          debugPrint('   Stack trace: $stackTrace');
          debugPrint('   Pending navigation will be handled by AuthGate');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('⏳ Navigator not ready, will be handled by AuthGate lifecycle');
      }
    }
  }

  // Store pending navigation for handling after app loads
  String? _pendingChatNavigation;

  /// Get and clear pending chat navigation
  String? getPendingChatNavigation() {
    if (kDebugMode) {
      debugPrint('📞 getPendingChatNavigation() called');
      debugPrint('   Current pending value: $_pendingChatNavigation');
    }
    final pending = _pendingChatNavigation;
    _pendingChatNavigation = null;
    if (kDebugMode) {
      debugPrint('   Returning: $pending (pending cleared)');
    }
    return pending;
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Local notification tapped: ${response.payload}');
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
        debugPrint('⚠️ Cannot enable notifications: Firebase not initialized');
      }
      throw Exception(
          'Firebase not initialized. Add Firebase configuration files first.');
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
      throw Exception(
          'Firebase not initialized. Add Firebase configuration files first.');
    }

    final settings = await _requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await initialize();
      return true;
    }
    return false;
  }
}
