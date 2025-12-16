import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service to securely store and retrieve webmail credentials
class WebmailCredentialsService {
  static final WebmailCredentialsService _instance = 
      WebmailCredentialsService._internal();
  factory WebmailCredentialsService() => _instance;
  WebmailCredentialsService._internal();

  final _storage = const FlutterSecureStorage();
  static const _usernameKey = 'webmail_username';
  static const _passwordKey = 'webmail_password';
  static const _rememberKey = 'webmail_remember';

  /// Save credentials securely
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    try {
      await _storage.write(key: _usernameKey, value: username);
      await _storage.write(key: _passwordKey, value: password);
      await _storage.write(key: _rememberKey, value: 'true');
      debugPrint('✅ Webmail credentials saved securely');
    } catch (e) {
      debugPrint('❌ Error saving webmail credentials: $e');
      rethrow;
    }
  }

  /// Get saved credentials
  Future<Map<String, String>?> getCredentials() async {
    try {
      final remember = await _storage.read(key: _rememberKey);
      if (remember != 'true') {
        return null;
      }

      final username = await _storage.read(key: _usernameKey);
      final password = await _storage.read(key: _passwordKey);

      if (username != null && password != null) {
        debugPrint('✅ Webmail credentials retrieved');
        return {
          'username': username,
          'password': password,
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error retrieving webmail credentials: $e');
      return null;
    }
  }

  /// Check if credentials are saved
  Future<bool> hasCredentials() async {
    try {
      final remember = await _storage.read(key: _rememberKey);
      return remember == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Clear saved credentials
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _usernameKey);
      await _storage.delete(key: _passwordKey);
      await _storage.delete(key: _rememberKey);
      debugPrint('✅ Webmail credentials cleared');
    } catch (e) {
      debugPrint('❌ Error clearing webmail credentials: $e');
      rethrow;
    }
  }
}
