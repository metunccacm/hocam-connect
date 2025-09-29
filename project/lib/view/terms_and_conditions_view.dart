import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';

class TermsAndConditionsView extends StatelessWidget {
  const TermsAndConditionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              GestureDetector(
                onTap:() {
                  Navigator.pop(context);
                },
              ),
              Text(
                "Terms & Conditions",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),            ],
          ),
        ],
      ),
    );
  }
}