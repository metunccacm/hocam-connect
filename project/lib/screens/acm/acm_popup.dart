import 'dart:math';
import 'package:flutter/material.dart';

class BubbleMenuDemo extends StatefulWidget {
  const BubbleMenuDemo({super.key});

  @override
  _BubbleMenuDemoState createState() => _BubbleMenuDemoState();
}

class _BubbleMenuDemoState extends State<BubbleMenuDemo> 
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  void toggleMenu() {
    setState(() {
      isExpanded = !isExpanded;
      isExpanded ? _controller.forward() : _controller.reverse();
    });
  }

  Widget buildBubble(IconData icon, VoidCallback onTap, double angle) {
    final double radius = 100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double dx = radius * _animation.value * cos(angle);
        final double dy = radius * _animation.value * sin(angle);
        return Positioned(
          right: 20 + dx,
          bottom: 20 + dy,
          child: Transform.scale(
            scale: _animation.value,
            child: FloatingActionButton(
              mini: true,
              onPressed: onTap,
              child: Icon(icon),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Expanded bubbles
          if (isExpanded)
            buildBubble(Icons.message, () => print('Message'), pi / 3),
          if (isExpanded)
            buildBubble(Icons.phone, () => print('Phone'), pi / 2),
          if (isExpanded)
            buildBubble(Icons.email, () => print('Email'), 2 * pi / 3),

          // Main button
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: toggleMenu,
              child: Icon(isExpanded ? Icons.close : Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}