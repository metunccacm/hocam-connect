import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:project/viewmodel/register_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;
  bool _acceptedPrivacyPolicy = false;

  // Password validation
  bool _isPasswordValid(String password) {
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacter =
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final hasMinLength = password.length >= 8;

    return hasUppercase &&
        hasLowercase &&
        hasDigit &&
        hasSpecialCharacter &&
        hasMinLength;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (!_isPasswordValid(v)) {
      return 'Must include uppercase, lowercase, number, special character, and 8+ chars';
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChangeNotifierProvider(
      create: (context) => RegistrationViewModel(),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: HCAppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
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
                      decoration: InputDecoration(
                        labelText: "Name",
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: colorScheme.outline),
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
                      decoration: InputDecoration(
                        labelText: "Surname",
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: colorScheme.outline),
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
                      decoration: InputDecoration(
                        labelText: "Email (...@metu.edu.tr)",
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: colorScheme.outline),
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
                      decoration: InputDecoration(
                        labelText: "Date of Birth (dd/mm/YY)",
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
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
                      onChanged: (_) {
                        // Rebuild to update the live checklist and revalidate repeat password
                        setState(() {});
                        _formKey.currentState?.validate();
                      },
                      decoration: InputDecoration(
                        labelText: "Password",
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        errorMaxLines: 3,
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
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 8),
                    _PasswordRulesChecklist(
                        valueListenable: _passwordController),
                    const SizedBox(height: 12),

                    // Repeat Password
                    TextFormField(
                      controller: _repeatPasswordController,
                      obscureText: _obscureRepeatPassword,
                      onChanged: (_) => _formKey.currentState?.validate(),
                      decoration: InputDecoration(
                        labelText: "Repeat Password",
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          borderSide: BorderSide(color: colorScheme.outline),
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

                    // Privacy Policy Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedPrivacyPolicy,
                          onChanged: (value) {
                            setState(() {
                              _acceptedPrivacyPolicy = value ?? false;
                            });
                          },
                          activeColor: colorScheme.primary,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface,
                                ),
                                children: [
                                  const TextSpan(text: 'I accept the '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        final uri = Uri.parse(
                                            'https://metuncc.acm.org/hocam-connect/privacy');
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Could not open privacy policy'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_acceptedPrivacyPolicy)
                      Padding(
                        padding: const EdgeInsets.only(left: 48.0, top: 4.0),
                        child: Text(
                          '* Required',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
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
                                  // Check privacy policy acceptance
                                  if (!_acceptedPrivacyPolicy) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please accept the Privacy Policy to continue'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

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
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        child: viewModel.isLoading
                            ? const CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
                        Text("Already have an account? ",
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant)),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Log in",
                            style: TextStyle(
                              color: colorScheme.primary,
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

class _PasswordRulesChecklist extends StatelessWidget {
  const _PasswordRulesChecklist({
    required this.valueListenable,
  });

  final ValueListenable<TextEditingValue> valueListenable;

  static final RegExp _uppercaseRegExp = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegExp = RegExp(r'[a-z]');
  static final RegExp _digitRegExp = RegExp(r'[0-9]');
  static final RegExp _specialRegExp = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  bool _hasUppercase(String s) => _uppercaseRegExp.hasMatch(s);
  bool _hasLowercase(String s) => _lowercaseRegExp.hasMatch(s);
  bool _hasDigit(String s) => _digitRegExp.hasMatch(s);
  bool _hasSpecial(String s) => _specialRegExp.hasMatch(s);
  bool _hasMinLength(String s) => s.length >= 8;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: valueListenable,
      builder: (context, value, _) {
        final s = value.text;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RuleRow(label: 'Uppercase letter', ok: _hasUppercase(s)),
                _RuleRow(label: 'Lowercase letter', ok: _hasLowercase(s)),
                _RuleRow(label: 'Number', ok: _hasDigit(s)),
                _RuleRow(
                    label: 'Special character ( !@#\$%^&*(),.?":{}|<> )',
                    ok: _hasSpecial(s)),
                _RuleRow(label: 'At least 8 characters', ok: _hasMinLength(s)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Theme.of(context).colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
