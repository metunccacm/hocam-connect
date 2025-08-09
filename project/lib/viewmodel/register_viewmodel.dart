import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RegistrationViewModel extends ChangeNotifier {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final dobController = TextEditingController();

  bool isLoading = false;

  // Pick date of birth
  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      notifyListeners();
    }
  }

  // Registration validation
  Future<void> register({required String name, required String surname, required String email, required String password, required String dob}) async {
    if (!formKey.currentState!.validate()) return;

    isLoading = true;
    notifyListeners();

    try {
      // Simulate a registration process
      await Future.delayed(const Duration(seconds: 2));

      debugPrint("Name: ${nameController.text}");
      debugPrint("Email: ${emailController.text}");
      debugPrint("Password: ${passwordController.text}");
      debugPrint("DOB: ${dobController.text}");
    } catch (e) {
      debugPrint("Kayıt hatası: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    dobController.dispose();
    super.dispose();
  }
}
