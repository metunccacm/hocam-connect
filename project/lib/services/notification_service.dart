import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
  // Handle background message here if needed
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
      
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permission
      final notificationSettings = await _requestPermission();

      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.authorized) {
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

  /// Save token to Supabase
  Future<void> _saveTokenToSupabase(String token, String userId) async {
    try {
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      
      if (kDebugMode) {
        print('FCM token saved to Supabase');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token to Supabase: $e');
      }
    }
  }

  /// Delete token from Supabase
  Future<void> deleteTokenFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('fcm_tokens')
            .delete()
            .eq('user_id', user.id);
        
        if (kDebugMode) {
          print('FCM token deleted from Supabase');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting FCM token from Supabase: $e');
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
      print('Foreground message received: ${message.notification?.title}');
    }

    // Show local notification when app is in foreground
    if (message.notification != null) {
      _showLocalNotification(message);
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

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification tapped: ${message.data}');
    }
    // TODO: Navigate to specific screen based on message.data
    // Example: if (message.data['type'] == 'chat') { navigate to chat }
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
