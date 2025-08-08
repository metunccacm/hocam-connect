import 'package:flutter/material.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 2),
              // Logo
              Center(
                child: Image.asset(
                  'assets/logo.png', // Replace with your logo asset path
                  height: 150,
                ),
              ),
              const SizedBox(height: 30),
              // Text "Welcome to Hocam Connect"
              const Text(
                'Welcome to Hocam Connect',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              // Text "by"
              const Text(
                'by',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              // ACM logo
              Center(
                child: Image.asset(
                  'assets/acm_logo.png', // Replace with your ACM logo asset path
                  height: 80,
                ),
              ),
              const Spacer(flex: 3),
              // "Get Started" button
              ElevatedButton(
                onPressed: () {
                  // Navigate to the registration screen
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 20),
              // "Log in" button
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to the login screen
                    Navigator.pushNamed(context, '/');
                  },
                  child: const Text(
                    'Already have an account? Log in',
                    style: TextStyle(
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}