import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityGate extends StatefulWidget {
  final Widget child;               // Your real app content
  final Duration retryBackoffMin;
  final Duration retryBackoffMax;
  final List<String>? funnyMessages;

  const ConnectivityGate({
    super.key,
    required this.child,
    this.retryBackoffMin = const Duration(seconds: 2),
    this.retryBackoffMax = const Duration(seconds: 6),
    this.funnyMessages,
  });
  
  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  final _rng = Random();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _funnyTimer;
  String _funny = 'Warming up the hamsters…';
  bool _checking = true;
  bool _online = false;

  static const _fallbackFunny = <String>[
    'Negotiating with the Wi-Fi gods…',
    'Untangling some ethernet cables…',
    'Asking the router nicely…',
    'Counting packets: 1, 2, 404…',
    'Summoning DNS spirits…',
  ];

  List<String> get _messages => widget.funnyMessages ?? _fallbackFunny;

  @override
  void initState() {
    super.initState();
    _startFunnyCycler();
    _startConnectivityStream();
    _checkNow();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _funnyTimer?.cancel();
    super.dispose();
  }

  void _startFunnyCycler() {
    _setRandomFunny();
    _funnyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_checking) _setRandomFunny();
    });
  }

  void _setRandomFunny() {
    setState(() => _funny = _messages[_rng.nextInt(_messages.length)]);
  }

  void _startConnectivityStream() {
    _connSub = Connectivity().onConnectivityChanged.listen((_) => _checkNow());
  }

  Future<void> _checkNow() async {
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
      setState(() {
        _online = hasInternet;
        _checking = false;
      });

      if (!hasInternet) {
        final min = widget.retryBackoffMin.inMilliseconds;
        final max = widget.retryBackoffMax.inMilliseconds;
        final ms = min + _rng.nextInt((max - min).clamp(0, 60000));
        Future.delayed(Duration(milliseconds: ms), () {
          if (mounted && !_online) _checkNow();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return widget.child;
    return _NoInternetView(
      checking: _checking,
      funny: _funny,
      onRetry: _checking ? null : _checkNow,
    );
  }
}

class _NoInternetView extends StatelessWidget {
  final bool checking;
  final String funny;
  final VoidCallback? onRetry;

  const _NoInternetView({
    required this.checking,
    required this.funny,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 160,
                  child: Image.asset(
                    'assets/illustrations/no_internet.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.wifi_off, size: 96),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  checking ? 'Checking your connection…' : 'No Internet Connection',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  checking
                      ? funny
                      : 'Please check your Wi-Fi or mobile data and try again.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  height: 44,
                  child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    alignment: Alignment.center,
                    padding: EdgeInsets.zero,
                  ),
                  child: Center(
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Try Again'),
                    ],
                    ),
                  ),
                  ),
                ),
                const SizedBox(height: 12),
                if (checking) const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
