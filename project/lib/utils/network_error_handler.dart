import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Custom exception for network-related errors
class HC50Exception implements Exception {
  final String message;
  final String? details;
  final dynamic originalError;

  HC50Exception({
    this.message = 'Network connectivity error',
    this.details,
    this.originalError,
  });

  @override
  String toString() {
    return 'HC-50: $message${details != null ? '\nDetails: $details' : ''}';
  }
}

/// Network error handler utility
class NetworkErrorHandler {
  /// Check if an error is network-related
  static bool isNetworkError(dynamic error) {
    if (error is HC50Exception) return true;
    
    final errorString = error.toString().toLowerCase();
    
    // Common network error patterns
    return errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable') ||
        errorString.contains('no internet') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        error is SocketException ||
        error is TimeoutException;
  }

  /// Check current connectivity status
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasAny = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);

      if (!hasAny) return false;

      return await InternetConnection().hasInternetAccess;
    } catch (_) {
      return false;
    }
  }

  /// Wrap a network call with error handling
  static Future<T> handleNetworkCall<T>(
    Future<T> Function() call, {
    String? context,
  }) async {
    try {
      // Check connectivity before making the call
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw HC50Exception(
          message: 'No internet connection available',
          details: context ?? 'Please check your network settings',
        );
      }

      return await call();
    } on HC50Exception {
      rethrow;
    } catch (error) {
      if (isNetworkError(error)) {
        throw HC50Exception(
          message: 'Network connection error',
          details: context ?? 'Unable to reach server',
          originalError: error,
        );
      }
      // Re-throw non-network errors
      rethrow;
    }
  }

  /// Show error dialog with HC-50 code
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Error Code: HC-50',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a snackbar with HC-50 error
  static void showErrorSnackBar(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Error HC-50',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// Widget to wrap content with network error handling
class NetworkErrorBoundary extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRetry;
  final String? errorMessage;

  const NetworkErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Error state widget for network errors
class NetworkErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  const NetworkErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              'Error HC-50',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message ?? 'Network connection error',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Error HC-50',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Network Connection Error',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Unable to connect to the server.\nPlease check your internet connection.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
