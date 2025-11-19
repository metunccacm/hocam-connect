import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../services/notification_repository.dart';

/// Debug screen to test push notifications
/// Add this to your routes to access it for testing
class NotificationDebugView extends StatefulWidget {
  const NotificationDebugView({super.key});

  @override
  State<NotificationDebugView> createState() => _NotificationDebugViewState();
}

class _NotificationDebugViewState extends State<NotificationDebugView> {
  final _supabase = Supabase.instance.client;
  String _status = 'Ready to test';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    setState(() {
      _status = 'Checking setup...';
    });

    final checks = <String>[];

    // Check 1: User logged in
    final user = _supabase.auth.currentUser;
    if (user != null) {
      checks.add('✅ User logged in: ${user.email}');
    } else {
      checks.add('❌ No user logged in');
    }

    // Check 2: Notification permission
    final hasPermission = await NotificationService().hasPermission();
    checks.add(hasPermission
        ? '✅ Notification permission granted'
        : '❌ Notification permission denied');

    // Check 3: FCM token
    final token = NotificationService().currentToken;
    if (token != null) {
      checks.add('✅ FCM token: ${token.substring(0, 20)}...');
    } else {
      checks.add('❌ No FCM token');
    }

    // Check 4: Token in database
    try {
      final response = await _supabase
          .from('fcm_tokens')
          .select()
          .eq('user_id', user!.id)
          .maybeSingle();

      if (response != null) {
        checks.add('✅ Token saved in database');
        checks.add('   Platform: ${response['platform']}');
        checks.add('   Updated: ${response['updated_at']}');
      } else {
        checks.add('❌ Token not found in database');
      }
    } catch (e) {
      checks.add('❌ Error checking database: $e');
    }

    // Check 5: Notifications table exists
    try {
      await _supabase.from('notifications').select().limit(1);
      checks.add('✅ Notifications table exists');
    } catch (e) {
      checks.add('❌ Notifications table error: $e');
    }

    setState(() {
      _status = checks.join('\n');
    });
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Sending test notification...';
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _status = '❌ Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Send notification to yourself
      final notificationId = await NotificationRepository.sendToUser(
        userId: user.id,
        title: 'Test Notification',
        body: 'This is a test notification from the debug screen',
        data: {'test': true, 'timestamp': DateTime.now().toIso8601String()},
        notificationType: 'test',
      );

      setState(() {
        _status =
            '✅ Test notification sent!\nNotification ID: $notificationId\n\nWait a few seconds...';
      });

      // Wait and check status
      await Future.delayed(const Duration(seconds: 3));

      final status =
          await NotificationRepository.getNotificationStatus(notificationId);

      if (status != null) {
        setState(() {
          _status = '✅ Notification ID: $notificationId\n'
              'Status: ${status['status']}\n'
              'Created: ${status['created_at']}\n'
              'Sent: ${status['sent_at'] ?? 'Not sent yet'}\n'
              'Error: ${status['error_message'] ?? 'None'}\n\n'
              'Check your device notifications!';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendDirectSQL() async {
    setState(() {
      _isLoading = true;
      _status = 'Sending via SQL...';
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _status = '❌ Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Insert directly into notifications table
      final response = await _supabase
          .from('notifications')
          .insert({
            'user_id': user.id,
            'sender_id': user.id,
            'title': 'Direct SQL Test',
            'body': 'This notification was inserted directly via SQL',
            'data': {'test': true, 'method': 'direct_sql'},
            'notification_type': 'test',
            'status': 'pending',
          })
          .select()
          .single();

      final notificationId = response['id'];

      setState(() {
        _status =
            '✅ Inserted into database!\nID: $notificationId\n\nWait 3 seconds...';
      });

      // Wait for trigger to fire
      await Future.delayed(const Duration(seconds: 3));

      final status =
          await NotificationRepository.getNotificationStatus(notificationId);

      if (status != null) {
        setState(() {
          _status = '✅ Notification ID: $notificationId\n'
              'Status: ${status['status']}\n'
              'Created: ${status['created_at']}\n'
              'Sent: ${status['sent_at'] ?? 'Not sent yet'}\n'
              'Error: ${status['error_message'] ?? 'None'}\n\n'
              '${status['status'] == 'sent' ? '✅ Success! Check device' : '❌ Check error message'}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _viewRecentNotifications() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading notifications...';
    });

    try {
      final notifications =
          await NotificationRepository.getUserNotifications(limit: 10);

      if (notifications.isEmpty) {
        setState(() {
          _status = 'No notifications found';
        });
      } else {
        final lines = <String>['Recent notifications:\n'];
        for (var notif in notifications) {
          lines.add('${notif['title']}');
          lines.add('  Status: ${notif['status']}');
          lines.add('  Type: ${notif['notification_type'] ?? 'none'}');
          lines.add('  Created: ${notif['created_at']}');
          if (notif['error_message'] != null) {
            lines.add('  Error: ${notif['error_message']}');
          }
          lines.add('');
        }
        setState(() {
          _status = lines.join('\n');
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting permissions...';
    });

    try {
      final success = await NotificationService().requestPermissionAgain();
      setState(() {
        _status = success
            ? '✅ Permission granted! FCM token: ${NotificationService().currentToken}'
            : '❌ Permission denied';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkSetup,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Setup Check'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testPermissions,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Test Permissions'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendTestNotification,
              icon: const Icon(Icons.send),
              label: const Text('Send Test (via Repository)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendDirectSQL,
              icon: const Icon(Icons.storage),
              label: const Text('Send Test (Direct SQL)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _viewRecentNotifications,
              icon: const Icon(Icons.list),
              label: const Text('View Recent Notifications'),
            ),
            const SizedBox(height: 24),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            const Divider(),
            const Text(
              'Troubleshooting Tips:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Make sure you have enabled notifications in Settings\n'
              '2. Check that FCM token is saved to database\n'
              '3. Verify Edge Function is deployed\n'
              '4. Check Supabase database settings (supabase_url, anon_key)\n'
              '5. Ensure HTTP extension is enabled\n'
              '6. Check notification status after sending',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
