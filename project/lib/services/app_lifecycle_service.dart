import 'package:flutter/material.dart';

/// Service to track app lifecycle state and manage in-app notifications
/// Used to determine whether to show full push notifications or in-app snackbars
class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  final List<Function(AppLifecycleState)> _listeners = [];

  /// Get current app state
  AppLifecycleState get currentState => _currentState;

  /// Check if app is in foreground (user can see it)
  bool get isInForeground => _currentState == AppLifecycleState.resumed;

  /// Check if app is in background or terminated
  bool get isInBackground =>
      _currentState != AppLifecycleState.resumed;

  /// Initialize the service (call once in main.dart)
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Dispose the service
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Add listener for state changes
  void addListener(Function(AppLifecycleState) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(Function(AppLifecycleState) listener) {
    _listeners.remove(listener);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _currentState = state;
    print('🔄 App lifecycle state changed: $state');

    // Notify all listeners
    for (final listener in _listeners) {
      listener(state);
    }
  }
}

/// Global context key for showing in-app notifications
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Show in-app notification (WhatsApp-style snackbar)
void showInAppNotification({
  required String title,
  required String message,
  String? avatarUrl,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  // Clear any existing snackbars
  messenger.clearSnackBars();

  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 600),
      content: GestureDetector(
        onTap: () {
          messenger.hideCurrentSnackBar();
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
