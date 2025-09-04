import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_controller.dart'; //Theme Controller

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

  // ACCOUNT DELETE WILL BE IMPLEMENTED LATER!!!!
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will delete your profile data and avatar, then sign you out. '
          'Your authentication record may remain until an admin purges it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = _supa.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active user')),
      );
      return;
    }

    setState(() => _busy = true);

    String msg = 'Account data deleted';
    try {
      // 1) Storage: avatars/<uid> içini sil
      final prefix = 'avatars/${user.id}';

      // Parti parti listele ve sil (v2 API: named params)
      List<FileObject> batch = await _supa.storage.from(_bucket).list(
        path: prefix,
        searchOptions: const SearchOptions(limit: 100, offset: 0),
      );
      var offset = 0;

      while (batch.isNotEmpty) {
        final keys = batch.map((o) => '$prefix/${o.name}').toList();
        try {
          if (keys.isNotEmpty) {
            await _supa.storage.from(_bucket).remove(keys);
          }
        } catch (e) {
          // ignore: avoid_print
          print('Storage remove warning: $e');
        }

        offset += batch.length;
        batch = await _supa.storage.from(_bucket).list(
          path: prefix,
          searchOptions: SearchOptions(limit: 100, offset: offset),
        );
      }

      // 2) public.profiles satırını sil (RLS policy gerekir)
      try {
        await _supa.from('profiles').delete().eq('id', user.id);
      } catch (e) {
        // Silinemezse "deactivate" deneyelim
        // ignore: avoid_print
        print('profiles delete warning: $e');
        try {
          await _supa.from('profiles').update({'deactivated': true}).eq('id', user.id);
          msg = 'Account deactivated';
        } catch (_) {}
      }

      // 3) Oturumu kapat ve çık
      await _supa.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deletion failed: $e')),
      );
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
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Settings', style: TextStyle(fontSize: 17)),
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
