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

  Future<void> loginUser(BuildContext context) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (!EmailValidator.validate(email)) {
      _errorMessage = 'Please enter a valid email address.';
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters long.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await _authService.signIn(email: email, password: password);

      emailController.clear();
      passwordController.clear();

      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
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
