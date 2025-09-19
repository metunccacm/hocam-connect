import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';

class HitchhikeView extends StatelessWidget {
  const HitchhikeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HCAppBar(title: 'Hitchhike'),
      body: const Center(
        child: Text('Hitchhike  coming soon!'),
      ),
    );
  }
}