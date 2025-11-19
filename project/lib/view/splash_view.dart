import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class SplashView extends StatefulWidget {
  final Widget child;
  final List<String>? funnyMessages;

  const SplashView({
    super.key,
    required this.child,
    this.funnyMessages,
  });

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  final _rng = Random();
  Timer? _funnyTimer;
  String _funny = 'Warming up the hamsters…';
  bool _checking = true;
  bool _hasInternet = false;

  static const _fallbackFunny = <String>[
    'Negotiating with the Wi-Fi gods…',
    'Untangling some ethernet cables…',
    'Asking the router nicely…',
    'Counting packets: 1, 2, 404…',
    'Summoning DNS spirits…',
    'Polishing the antenna…',
    'Waving at the router 👋',
    'Asking packets to hurry up…',
    'Consulting the fiber oracle…',
  ];

  List<String> get _messages => widget.funnyMessages ?? _fallbackFunny;

  @override
  void initState() {
    super.initState();
    _startFunnyCycler();
    _checkConnection();
  }

  @override
  void dispose() {
    _funnyTimer?.cancel();
    super.dispose();
  }

  void _startFunnyCycler() {
    _setRandomFunny();
    _funnyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_checking && mounted) _setRandomFunny();
    });
  }

  void _setRandomFunny() {
    setState(() => _funny = _messages[_rng.nextInt(_messages.length)]);
  }

  Future<void> _checkConnection() async {
    setState(() => _checking = true);

    try {
      final results = await Connectivity().checkConnectivity();
      final hasAny = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);

      bool hasInternet = false;
      if (hasAny) {
        hasInternet = await InternetConnection().hasInternetAccess;
      }

      if (!mounted) return;

      if (hasInternet) {
        // Connection successful! Proceed to app
        setState(() {
          _hasInternet = true;
          _checking = false;
        });
      } else {
        // No internet, show error state
        setState(() {
          _hasInternet = false;
          _checking = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasInternet = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have internet, show the actual app
    if (_hasInternet) {
      return widget.child;
    }

    // Otherwise, show splash screen with connectivity check
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                SizedBox(
                  height: 200,
                  child: Image.asset(
                    'assets/logo/hc_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school,
                      size: 120,
                      color: Color(0xFF007BFF),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Status
                if (_checking) ...[
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF007BFF)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Checking your connection…',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _funny,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  // No internet error
                  const Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Internet Connection',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your Wi-Fi or mobile data and try again.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _checkConnection,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
