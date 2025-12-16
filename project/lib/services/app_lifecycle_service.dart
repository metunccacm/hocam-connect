import 'package:flutter/material.dart';

/// Service to track app lifecycle state
/// Used to determine app state for notification handling
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
  bool get isInBackground => _currentState != AppLifecycleState.resumed;

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
    print('   - isInForeground: $isInForeground');
    print('   - isInBackground: $isInBackground');

    // Notify all listeners
    for (final listener in _listeners) {
      listener(state);
    }
  }
}
