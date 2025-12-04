import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:project/view/chat_list_view.dart';

class ThisWeekView extends StatefulWidget {
  const ThisWeekView({super.key});

  @override
  State<ThisWeekView> createState() => _ThisWeekViewState();
}

class _ThisWeekViewState extends State<ThisWeekView>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasConnection = true;
  String _currentUrl = '';
  static const String _targetUrl =
      'https://ncc.metu.edu.tr/this-week-on-campus/#node-6315';

  @override
  bool get wantKeepAlive => true;
  // safeguard added against memory leak
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _safeSetState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            _safeSetState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (error) {
            _safeSetState(() {
              _isLoading = false;
              _hasConnection = false;
            });
          },
        ),
      )
      ..setBackgroundColor(const Color(0x00000000));

    _checkConnectionAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset to target URL when view becomes active again
    _ensureCorrectPage();
  }

  Future<void> _ensureCorrectPage() async {
    // Only reload if we're not already on the target page or loading it
    if (_currentUrl.isNotEmpty &&
        !_currentUrl.startsWith(_targetUrl) &&
        !_isLoading) {
      await _controller.loadRequest(Uri.parse(_targetUrl));
    }
  }

  Future<void> _checkConnectionAndLoad() async {
    final result = await Connectivity().checkConnectivity();
    final hasNet = !result.contains(ConnectivityResult.none);
    _safeSetState(() {
      _hasConnection = hasNet;
    });
    if (!hasNet || !mounted) return;
    await _controller.loadRequest(Uri.parse(_targetUrl));
  }

  Future<void> _refresh() async {
    _safeSetState(() {
      _isLoading = true;
    });
    await _controller.reload();
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      await _controller.goForward();
    }
  }

  @override
  void dispose() {
    // Dispose the WebViewController to prevent crashes during app termination
    // This ensures proper cleanup before the Flutter engine is destroyed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return AppScaffold(
      title: 'This Week on Campus',
      actions: [
        // IconButton(
        //   icon: const Icon(Icons.chat_bubble_outline),
        //   tooltip: 'Chats',
        //   onPressed: () {
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(builder: (_) => const ChatListView()),
        //     );
        //   },
        // ),
      ],
      body: !_hasConnection
          ? _buildErrorView()
          : Column(
              children: [
                // Navigation bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _goBack,
                        tooltip: 'Back',
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _goForward,
                        tooltip: 'Forward',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refresh,
                        tooltip: 'Refresh',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentUrl.isNotEmpty
                                ? Uri.parse(_currentUrl).host
                                : 'ncc.metu.edu.tr',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // WebView
                Expanded(
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
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
