import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_controller.dart'; //Theme Controller

import 'terms_and_conditions_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // UI state
  bool notificationsEnabled = true;
  bool _isDark = ThemeController.instance.isDark;
  bool _busy = false;

  // Supabase
  static const _bucket = 'profile'; // storage bucket adın
  final _supa = Supabase.instance.client;

  // THEME
  Future<void> _toggleTheme(bool value) async {
    setState(() => _isDark = value);
    await ThemeController.instance.toggleDark(value); // Light/Dark
  }

  Future<void> _useSystemTheme() async {
    await ThemeController.instance.useSystem();
    setState(() => _isDark = ThemeController.instance.isDark);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme follows system')),
    );
  }

  // NOTIFICATIONS (placeholder)
  void _toggleNotifications(bool value) {
    setState(() => notificationsEnabled = value);
    // Bildirim entegrasyonunu burada yapacağız.
  }

Future<void> _deleteAccount() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account'),
      content: const Text(
        'This will permanently delete your account and related data. This action cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (confirm != true) return;

  final user = _supa.auth.currentUser;
  if (user == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active user')));
    return;
  }

  setState(() => _busy = true);
  try {
    // Edge Function call (uses user’s JWT automatically if signed in)
    final resp = await _supa.functions.invoke('account-delete', body: {});
    if (resp.status != 200) {
      throw Exception('Function error: ${resp.data}');
    }

    // Sign out locally (the auth user is already deleted server-side)
    await _supa.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true)
    .pushNamedAndRemoveUntil('/welcome', (route) => false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account was deleted.')));
    Navigator.of(context).popUntil((r) => r.isFirst);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}


  // EMAIL
  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'hcsup@metuncc.acm.org',
      query: 'subject=Request%20New%20Feature',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ThemeController.instance.mode;

    final overlay = _busy
        ? Container(
            color: Colors.black45,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        Scaffold(
          appBar: const HCAppBar(
            title: 'Settings',
          ),
          body: ListView(
            children: [
              const SizedBox(height: 32),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            // THEME
                            ListTile(
                              leading: Icon(
                                Icons.dark_mode,
                                color: _isDark ? Colors.amber : Colors.grey,
                              ),
                              title: const Text('Dark Mode'),
                              subtitle: Text(
                                mode == ThemeMode.system
                                    ? 'Following system'
                                    : (mode == ThemeMode.dark ? 'Dark' : 'Light'),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Switch.adaptive(
                                value: _isDark,
                                onChanged: _toggleTheme,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _useSystemTheme,
                                icon: const Icon(Icons.settings_suggest, size: 16),
                                label: const Text('Use system theme'),
                              ),
                            ),

                            // NOTIFICATIONS
                            ListTile(
                              leading: Icon(
                                Icons.notifications,
                                color: notificationsEnabled ? Colors.blue : Colors.grey,
                              ),
                              title: const Text('Notifications'),
                              trailing: Switch.adaptive(
                                value: notificationsEnabled,
                                onChanged: _toggleNotifications,
                              ),
                            ),

                            // Terms & Conditions
                            ListTile(
                              title: const Text('Terms & Conditions'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TermsAndConditionsView(),
                                  ),
                                );
                              },
                            ),

                            const Divider(),

                            // DELETE ACCOUNT
                            ListTile(
                              leading: const Icon(Icons.delete, color: Colors.red),
                              title: const Text('Delete Account'),
                              subtitle: const Text(
                                'Deletes profile & avatar, then signs out',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.red),
                              onTap: _deleteAccount,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Hocam Connect by ACM v0.1',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDark ? Colors.grey : Theme.of(context).primaryColorDark,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _launchEmail,
                      child: Text(
                        'Request new feature or report a bug',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: _isDark ? Colors.grey : Theme.of(context).primaryColorDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        overlay,
      ],
    );
  }
}
