import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // AuthException için
import '../model/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _emailError = '';
  String get emailError => _emailError;

  String _passwordError = '';
  String get passwordError => _passwordError;

  Future<void> loginUser(BuildContext context) async {
    _isLoading = true;
    _errorMessage = '';
    _emailError = '';
    _passwordError = '';
    notifyListeners();

    final email = emailController.text.trim();
    final password = passwordController.text;

    bool hasError = false;

    if (email.isEmpty) {
      _emailError = 'Email is required';
      hasError = true;
    } else if (!EmailValidator.validate(email)) {
      _emailError = 'Please enter a valid email address';
      hasError = true;
    }

    if (password.isEmpty) {
      _passwordError = 'Password is required';
      hasError = true;
    } else if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters long';
      hasError = true;
    }

    if (hasError) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await _authService.signIn(email: email, password: password);

      emailController.clear();
      passwordController.clear();

      if (context.mounted) {
        // Check if we can pop (meaning we are on top of AuthGate/WelcomeView)
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          // If we can't pop, we are likely the root, so we restart the app flow
          // We use pushReplacement to /home or / depending on setup, 
          // but since we want to trigger AuthGate logic, we should probably go to /
          // However, let's try popping first. If that fails, we force /home 
          // BUT /home bypasses onboarding. 
          // So we should navigate to a route that uses AuthGate.
          // Since / isn't a named route in routes map (it's home), 
          // let's try pushing a new MaterialPageRoute with AuthGate if needed.
          // But for now, let's assume pop works or we use pushReplacementNamed('/')
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
