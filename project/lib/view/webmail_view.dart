import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:project/view/chat_list_view.dart';

class WebmailView extends StatefulWidget {
  const WebmailView({super.key});

  @override
  State<WebmailView> createState() => _WebmailViewState();
}

class _WebmailViewState extends State<WebmailView> {
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
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within the webmail domain
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setBackgroundColor(const Color(0x00000000))
      // Enable cookies and local storage to persist login session
      ..enableZoom(true);

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
      // Load METU webmail
      _controller.loadRequest(
        Uri.parse('https://webmail.metu.edu.tr/'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'METU Webmail',
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Chats',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListView()),
            );
          },
        ),
      ],
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
