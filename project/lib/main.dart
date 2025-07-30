import 'package:flutter/material.dart';
import 'screens/acm/acm_popup.dart'; 

void main() => runApp(MaterialApp(home: BubbleMenuDemo()));

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
    );
  }
}