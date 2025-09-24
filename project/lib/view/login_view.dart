import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/login_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // Make the logo ~70% of screen width, clamp between 200–420 px
    final logoSize = (w * 0.70).clamp(200.0, 420.0);

    return Consumer<LoginViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 64),

                  // BIGGER hc_beta image (centered)
                  Center(
                    child: SizedBox(
                      width: logoSize,
                      height: math.min(logoSize, 360.0),
                      child: Image.asset(
                        'assets/images/hc_beta.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  const Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: viewModel.emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !viewModel.isLoading,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: viewModel.passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    enabled: !viewModel.isLoading,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/forgot-password',
                          arguments: viewModel.emailController.text,
                        );
                      },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Color(0xFF007BFF),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (viewModel.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: () async {
                        await viewModel.loginUser(context);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Login'),
                    ),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Not a member?",
                        style: TextStyle(color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          'Sign up now',
                          style: TextStyle(
                            color: Color(0xFF007BFF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
