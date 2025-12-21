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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    // Make the logo bigger - 75% of screen width, clamp between 280–500 px
    // Height based on screen height to scale properly
    final logoWidth = (w * 0.75).clamp(280.0, 500.0);
    final logoHeight = (h * 0.35).clamp(250.0, 420.0);

    return Consumer<LoginViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 32),

                  // BIGGER hc_beta image (centered)
                  Center(
                    child: SizedBox(
                      width: logoWidth,
                      height: logoHeight,
                      child: Image.asset(
                        theme.brightness == Brightness.dark
                        ? 'assets/hc_logo/hc_logo_bw.png' 
                        : 'assets/hc_logo/hc_logo_color.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: viewModel.emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      errorText: viewModel.emailError.isEmpty ? null : viewModel.emailError,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !viewModel.isLoading,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: viewModel.passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      errorText: viewModel.passwordError.isEmpty ? null : viewModel.passwordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: colorScheme.onSurfaceVariant,
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

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Not a member?",
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: Text(
                          'Sign up now',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
