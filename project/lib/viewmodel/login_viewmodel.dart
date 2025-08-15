import 'package:flutter/material.dart';
import '../model/auth_service.dart';
import 'package:email_validator/email_validator.dart';

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

    if (!EmailValidator.validate(emailController.text)) {
      _errorMessage = 'Please enter a valid email address.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (passwordController.text.length < 6) {
      _errorMessage = 'Password must be at least 6 characters long.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await _authService.signIn(
        email: emailController.text,
        password: passwordController.text,
      );

      // This is the key change for multi-screen navigation.
      Navigator.pushNamed(context, '/home');

      emailController.clear();
      passwordController.clear();
    } catch (e) {
      _errorMessage = e.toString();
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