import 'package:flutter/material.dart';
import 'package:project/view/gpa_calculator_view.dart';
import 'package:project/view/hitchike_view.dart';
import 'package:project/view/marketplace_view.dart';
import 'package:project/view/student_handbook_eng_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project/widgets/custom_appbar.dart';

import '../services/chat_service.dart';
// import 'chat_view.dart';
// import 'chat_list_view.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HCAppBar(
        title: 'Home Screen',
        actions: [
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Quick actions (8 little buttons) ----
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _quickActions(context),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _quickActions(BuildContext context) {
    // Fixed size so they pack like a flexbox; tweak 96→100 if you want larger.
    const double tileSize = 96;

    Widget tile({
      required IconData icon,
      required String label,
      required List<Color> gradient,
      required VoidCallback onTap,
    }) {
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

    return [
      tile(
        icon: Icons.book,
        label: 'Handbook',
        gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const StudentHandbookEngView())),
      ),
      tile(
        icon: Icons.calculate,
        label: 'GPA Calc',
        gradient: const [Color.fromARGB(255, 231, 83, 14), Color.fromARGB(255, 21, 105, 145)],
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GpaCalculatorView())),
      ),
      tile(
        icon: Icons.storefront,
        label: 'Marketplace',
        gradient: const [Color.fromARGB(255, 6, 153, 222), Color.fromARGB(255, 0, 133, 195)],
        onTap: () => Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => const MarketplaceView())),
      ),
      tile(
        icon: Icons.directions_car,
        label: 'Hitchhike',
        gradient: const [Color.fromARGB(255, 49, 255, 145), Color(0xFFF09819)],
        onTap: () => Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => const HitchikeView())),
      ),
      tile(
        icon: Icons.restaurant_menu_rounded,
        label: 'Cafeteria',
        gradient: const [Color(0xFFFF512F), Color(0xFFF09819)],
        onTap: () => _openOrSnack('/cafeteria-menu'),
      ),
      // --- NEW BUTTON FOR EXTERNAL LINKS ---
      tile(
        icon: Icons.link,
        label: 'Student Links',
        gradient: const [Color(0xFF614385), Color(0xFF516395)],
        onTap: () => _openOrSnack('/external-links'),
      ),
      // --- REMOVED BUTTONS ---
      // The tiles for TWOC, CET, Intranet, and ODTUCLASS have been removed from here.
      tile(
        icon: Icons.chat_bubble_outline,
        label: 'Sosyal',
        gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        onTap: () => _openOrSnack('/social'),
      ),
    ];
  }
}
