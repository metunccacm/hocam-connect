import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityGate extends StatefulWidget {
  final Widget child;

  const ConnectivityGate({
    super.key,
    required this.child,
  });
  
  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _startConnectivityStream();
    _checkConnectionSilently();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  void _startConnectivityStream() {
    _connSub = Connectivity().onConnectivityChanged.listen((_) {
      _checkConnectionSilently();
    });
  }

  Future<void> _checkConnectionSilently() async {
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _online = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_online)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                elevation: 4,
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No internet connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkConnectionSilently,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
