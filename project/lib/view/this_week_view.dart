import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ThisWeekView extends StatefulWidget {
  const ThisWeekView({super.key});

  @override
  State<ThisWeekView> createState() => _ThisWeekViewState();
}

class _ThisWeekViewState extends State<ThisWeekView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(
        Uri.parse('https://ncc.metu.edu.tr/this-week-on-campus/#node-6315'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('This Week on Campus')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
