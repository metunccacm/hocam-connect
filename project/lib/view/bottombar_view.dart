import 'package:flutter/material.dart';
import 'package:project/view/home_view.dart';


// This Week On Campus
class TWOC extends StatelessWidget {
  const TWOC({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('This Week On Campus')),
      body: const Center(child: Text('TWOC')),
    );
  }
}

// DM
class ChatView extends StatelessWidget {
  const ChatView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: const Center(child: Text('Chat Page')),
    );
  }
}

// Profile
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile Page')),
    );
  }
}

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false; // State to control the custom menu

  // Navigator keys for each tab to maintain their own navigation stacks
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  static const List<Widget> _rootPages = <Widget>[
    HomeView(),
    TWOC(),
    ChatView(),
    ProfileView(),
  ];

  void _onItemTapped(int index) {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
      });
    }
    if (_selectedIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Toggles the visibility of the custom pop-up menu
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (_isMenuOpen) {
          _toggleMenu();
          return;
        }
        if (didPop) return;
        final navigator = _navigatorKeys[_selectedIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        } else {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit App?'),
              content: const Text('Are you sure you want to exit?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes')),
              ],
            ),
          );
          if (shouldPop ?? false) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: List.generate(_rootPages.length, (index) {
                return Navigator(
                  key: _navigatorKeys[index],
                  onGenerateRoute: (routeSettings) {
                    return MaterialPageRoute(
                      builder: (context) => _rootPages[index],
                    );
                  },
                );
              }),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _toggleMenu, // Opens the custom menu
              shape: const CircleBorder(),
              backgroundColor: Colors.white,
              elevation: 2.0,
              child: _isMenuOpen
                  ? const Icon(Icons.close)
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/logo/acm_logo.png',
                      ),
                    ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
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
                            icon: Icons.star_border, label: 'TWOC', index: 1),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildTabItem(
                            icon: Icons.chat_bubble_outline,
                            label: 'Chat',
                            index: 2),
                        _buildTabItem(
                            icon: Icons.person_outline,
                            label: 'Profile',
                            index: 3),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
          // Custom menu overlay
          if (_isMenuOpen) _buildMenuOverlay(),
        ],
      ),
    );
  }

  // Builds the custom pop-up menu overlay
  Widget _buildMenuOverlay() {
    return Stack(
      children: [
        // Full-screen detector to close the menu when tapped outside
        GestureDetector(
          onTap: _toggleMenu,
          child: Container(
            color: Colors.black.withOpacity(0.4),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Positioned menu buttons
        Positioned(
          bottom: 95, // Position above the main FAB
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // GPA Calculator Button
              FloatingActionButton(
                onPressed: () {
                  _toggleMenu();
                  // TODO: Navigate to GPA Calculator page
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GPA Calculator Tapped')));
                },
                heroTag: 'gpa_calculator',
                backgroundColor: Colors.white,
                child: const Icon(Icons.calculate_outlined),
              ),
              const SizedBox(width: 15),
              // Placeholder Button 1
              FloatingActionButton(
                onPressed: () {
                  _toggleMenu();
                  // TODO: Implement action
                },
                heroTag: 'placeholder_1',
                backgroundColor: Colors.white,
                child: const Icon(Icons.sell_outlined),
              ),
              const SizedBox(width: 15),
              // Placeholder Button 2
              FloatingActionButton(
                onPressed: () {
                  _toggleMenu();
                  // TODO: Implement action
                },
                heroTag: 'placeholder_2',
                backgroundColor: Colors.white,
                child: const Icon(Icons.directions_car_outlined),
              ),
            ],
          ),
        ),
      ],
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