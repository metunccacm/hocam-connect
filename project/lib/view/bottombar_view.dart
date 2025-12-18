import 'package:flutter/material.dart';
import 'package:project/view/gpa_calculator_view.dart';

import 'package:project/view/home_view.dart';
import 'package:project/view/marketplace_view.dart';
import 'package:project/view/settings_view.dart';
import 'package:project/view/this_week_view.dart';
import 'package:project/view/hitchike_view.dart';
import 'package:project/view/webmail_view.dart';

import 'dart:math' as math;

class MainTabView extends StatefulWidget {
  final int initialIndex;
  const MainTabView({super.key, this.initialIndex = 0});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static const List<Widget> _pages = <Widget>[
    HomeView(),
    MarketplaceView(),
    WebmailView(),
    ThisWeekView(),
  ];

  void _onItemTapped(int index) {
    if (_animationController.isCompleted) {
      _animationController.reverse();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleMenu() {
    if (_animationController.isCompleted) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 MainTabView build called');
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          _buildMenuOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_menu_fab',
        shape: const CircleBorder(),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.white,
        elevation: 4.0,
        onPressed: _toggleMenu,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            // When menu is open, show a close icon
            if (_animationController.isCompleted) {
              return Icon(Icons.close,
                  color: Theme.of(context).colorScheme.onSurface);
            }
            // Otherwise, show the logo
            return Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset(
                isDark
                    ? 'assets/logo/hc_logo_dark.png'
                    : 'assets/logo/hc_logo.png',
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to regular logo if dark logo not found
                  return Image.asset(
                    'assets/logo/hc_logo.png',
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.apps,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildTabItem(icon: Icons.home, label: 'Home', index: 0),
                  _buildTabItem(
                      icon: Icons.storefront, label: 'Marketplace', index: 1),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildTabItem(
                      icon: Icons.email_outlined, label: 'Webmail', index: 2),
                  _buildTabItem(
                      icon: Icons.star_border, label: 'TWOC', index: 3),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // This widget builds the arc menu.
  Widget _buildMenuOverlay() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animationValue =
            CurvedAnimation(parent: _animationController, curve: Curves.easeOut)
                .value;
        // The menu is only visible when the animation is running or completed
        if (animationValue == 0) return const SizedBox.shrink();

        return Positioned.fill(
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Full-screen GestureDetector to close the menu
              GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  color: Colors.black.withOpacity(0.3 * animationValue),
                ),
              ),
              // GPA Calculator
              _buildMenuItem(
                icon: Icons.calculate_outlined,
                heroTag: 'menu_calc',
                angle: -135, // Top-left
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const GpaCalculatorView()),
                  );
                },
              ),
              // Marketplace
              _buildMenuItem(
                icon: Icons.settings,
                heroTag: 'menu_settings',
                angle: -90, // Top-center
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsView()),
                  );
                },
              ),
              // Hitchhike
              _buildMenuItem(
                icon: Icons.directions_car_outlined,
                heroTag: 'menu_hitch',
                angle: -45, // Top-right
                animationValue: animationValue,
                onPressed: () {
                  _toggleMenu();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HitchikeView()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to build and position each individual menu button
  Widget _buildMenuItem({
    required IconData icon,
    required String heroTag,
    required double angle,
    required double animationValue,
    required VoidCallback onPressed,
  }) {
    final radius = 80.0;
    final x = radius * math.cos(angle * math.pi / 180);
    final y = radius * math.sin(angle * math.pi / 180);

    return Positioned(
      bottom: -y, // Position above the FAB
      left:
          MediaQuery.of(context).size.width / 2 - 20 + x, // Center horizontally
      child: Transform.scale(
        scale: animationValue,
        child: FloatingActionButton(
          heroTag: heroTag,
          mini: true,
          onPressed: onPressed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Icon(icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final color =
        isSelected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return MaterialButton(
      minWidth: 40,
      onPressed: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
