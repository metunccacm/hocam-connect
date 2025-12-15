import 'package:flutter/material.dart';
import 'package:project/view/gpa_calculator_view.dart';
import 'package:project/view/hitchike_view.dart';
import 'package:project/view/marketplace_view.dart';
import 'package:project/view/student_handbook_eng_view.dart';
import 'package:project/view/delivery_menu_view.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/chat_service.dart';
import 'chat_list_view.dart';
import 'profile_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _svc = ChatService();
  // bool _busy = false;

  @override
  void initState() {
    super.initState();
    _svc.ensureMyLongTermKey();
  }

  Future<void> _openProfile() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileView()),
    );
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatListView()),
    );
  }

  // The tile widget helper
  Widget tile({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    // Fixed size so they pack like a flexbox
    const double tileSize = 96;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The route opening helper
  Object? _openOrSnack(String routeName) {
    // Avoid crashing if the route doesn't exist yet
    if (Navigator.canPop(context) || ModalRoute.of(context) != null) {
      return Navigator.pushNamed(context, routeName).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route not found: $routeName')),
        );
        return error;
      });
    }
    return null;
  }

  //  Widget for the section header
  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  // Logic for the confirmation dialog and launch
  Future<void> _showConfirmationDialogAndLaunch(String url,
      {String? displayName}) async {
    final bool isInternalRoute = url.startsWith('/');
    final String displayUrl = displayName ?? (isInternalRoute ? url : url);

    final bool? shouldLaunch = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Hocam Connect?'),
          content: Text(
              'You are about to navigate to $displayUrl. Do you want to continue?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Continue
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (shouldLaunch == true) {
      if (isInternalRoute) {
        _openOrSnack(url);
      } else {
        final uri = Uri.parse(url);
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open the website: $url')),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening link: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HCAppBar(
        title: 'Home Screen',
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chats',
            onPressed: _openChat,
          ),
          IconButton(
            icon: const Icon(Icons.account_box),
            tooltip: 'Profile',
            onPressed: _openProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Use the spread operator to flatten the list returned by _quickActions
          children: _quickActions(context),
        ),
      ),
    );
  }

  // The _quickActions function now only focuses on building the layout
  List<Widget> _quickActions(BuildContext context) {
    // --- 1. INTERNAL APP FEATURES ---
    List<Widget> internalActions = [
      tile(
        icon: Icons.book,
        label: 'Handbook',
        gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudentHandbookEngView())),
      ),
      tile(
        icon: Icons.calculate,
        label: 'GPA Calc',
        gradient: const [
          Color.fromARGB(255, 231, 83, 14),
          Color.fromARGB(255, 21, 105, 145)
        ],
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GpaCalculatorView())),
      ),
      tile(
        icon: Icons.storefront,
        label: 'Marketplace',
        gradient: const [
          Color.fromARGB(255, 6, 153, 222),
          Color.fromARGB(255, 0, 133, 195)
        ],
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MarketplaceView())),
      ),
      tile(
        icon: Icons.directions_car,
        label: 'Hitchhike',
        gradient: const [Color.fromARGB(255, 49, 255, 145), Color(0xFFF09819)],
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HitchikeView())),
      ),
      tile(
        icon: Icons.restaurant_menu_rounded,
        label: 'Cafeteria',
        gradient: const [Color(0xFFFF512F), Color(0xFFF09819)],
        onTap: () => _openOrSnack('/cafeteria-menu'),
      ),
      tile(
        icon: Icons.delivery_dining,
        label: 'Delivery',
        gradient: const [Color(0xFFFF9966), Color(0xFFFF5E62)],
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const DeliveryMenuView())),
      ),
      // tile(
      //   icon: Icons.chat_bubble_outline,
      //   label: 'Sosyal',
      //   gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      //   onTap: () => _openOrSnack('/social'),
      // ),
      tile(
        icon: Icons.campaign_rounded,
        label: 'TWOC',
        gradient: const [Color(0xFFee0979), Color(0xFFff6a00)],
        onTap: () => _openOrSnack('/twoc'),
      ),
    ];

    // --- 2. EXTERNAL LINK ACTIONS (Using confirmation dialog) ---
    List<Widget> externalActions = [
      tile(
        icon: Icons.email_outlined,
        label: 'Webmail',
        gradient: const [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
        onTap: () => _openOrSnack('/webmail'),
      ),
      tile(
        icon: Icons.calendar_today_rounded,
        label: 'CET',
        gradient: const [Color(0xFF614385), Color(0xFF516395)],
        onTap: () =>
            _showConfirmationDialogAndLaunch('https://cet.ncc.metu.edu.tr/'),
      ),
      tile(
        icon: Icons.private_connectivity_outlined,
        label: 'Intranet',
        gradient: const [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
        onTap: () => _showConfirmationDialogAndLaunch(
            'https://intranet.ncc.metu.edu.tr/'),
      ),
      tile(
        icon: Icons.school,
        label: 'ODTUCLASS',
        gradient: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
        onTap: () => _showConfirmationDialogAndLaunch(
            'https://odtuclass2025f.metu.edu.tr/'),
      ),
    ];

    //--- 3. FINAL RETURN LIST ---
    return [
      // Internal actions: centered in a Wrap
      Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: internalActions,
        ),
      ),

      // Separator and Header
      const SizedBox(height: 24),
      _buildHeader('External Links'),

      Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: externalActions,
        ),
      ),
    ];
  }
}
