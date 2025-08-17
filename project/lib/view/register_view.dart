import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project/viewmodel/register_viewmodel.dart';
import 'package:provider/provider.dart';

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});

  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  String? _passwordError;
  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;

  // Password validation
  bool _isPasswordValid(String password) {
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasSpecialCharacter =
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final hasMinLength = password.length >= 8;

    return hasUppercase && hasLowercase && hasSpecialCharacter && hasMinLength;
  }

  void _validatePassword(String value) {
    if (!_isPasswordValid(value)) {
      setState(() {
        _passwordError =
            "Password must have one uppercase, one lowercase, and one special character and at least 8 characters long";
      });
    } else {
      setState(() {
        _passwordError = null;
      });
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RegistrationViewModel(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF2F4F7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Consumer<RegistrationViewModel>(
          builder: (context, viewModel, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Register",
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Create an account to continue!",
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 24),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Name",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Surname
                    TextFormField(
                      controller: _surnameController,
                      decoration: const InputDecoration(
                        labelText: "Surname",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your surname';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email (...@metu.edu.tr)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.endsWith('@metu.edu.tr')) {
                          return 'Please use a metu.edu.tr email address';
                        }
                        if (!RegExp(
                                r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$")
                            .hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Date of Birth
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: "Date of Birth (dd/mm/YY)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                        ),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your date of birth';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: _validatePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (_passwordError != null) {
                          return _passwordError;
                        }
                        return null;
                      },
                    ),
                    if (_passwordError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          _passwordError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Repeat Password
                    TextFormField(
                      controller: _repeatPasswordController,
                      obscureText: _obscureRepeatPassword,
                      decoration: InputDecoration(
                        labelText: "Repeat Password",
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: Color(0xFFF0F0F0)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureRepeatPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureRepeatPassword = !_obscureRepeatPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please repeat your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: viewModel.isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              await viewModel.register(
                                context,
                                name: _nameController.text,
                                surname: _surnameController.text,
                                email: _emailController.text,
                                password: _passwordController.text,
                                dobText: _dobController.text,
                              );
                            }
                          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: viewModel.isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              )
                            : const Text(
                                "Register",
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Log in",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}