import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ThisWeekView extends StatefulWidget {
  const ThisWeekView({super.key});

  @override
  State<ThisWeekView> createState() => _ThisWeekViewState();
}

class _ThisWeekViewState extends State<ThisWeekView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasConnection = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _hasConnection = false;
            });
          },
        ),
      )
      ..setBackgroundColor(const Color(0x00000000));

    _checkConnectionAndLoad();
  }

  Future<void> _checkConnectionAndLoad() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      setState(() {
        _hasConnection = false;
      });
    } else {
      setState(() {
        _hasConnection = true;
      });
      _controller.loadRequest(
        Uri.parse('https://ncc.metu.edu.tr/this-week-on-campus/#node-6315'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'This Week on Campus',
      body: !_hasConnection
          ? _buildErrorView()
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No internet connection.\nPlease check your network.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _checkConnectionAndLoad,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
