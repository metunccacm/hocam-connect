import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // Error state is derived via validators; no separate state needed.
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

  // Removed unused _validatePass, consolidated into _validatePassword

  String? _validateConfirm(String? v) {
    if (v != _pass.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _pass.text.trim()),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please sign in.')),
      );

      // sign out to clear the temporary recovery session:
      await AuthService().signOut();

      // Navigate user back to your sign-in or root.
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update password.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _pass,
                obscureText: _obscure1,
                onChanged: (_) {
                  // Rebuild to update the live checklist and revalidate the form
                  setState(() {});
                  _formKey.currentState?.validate();
                },
                decoration: InputDecoration(
                  labelText: 'New password',
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                    icon: Icon(
                        _obscure1 ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 8),
              _PasswordRulesChecklist(valueListenable: _pass),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure2,
                onChanged: (_) => _formKey.currentState?.validate(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  errorMaxLines: 2,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(
                        _obscure2 ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: _validateConfirm,
              ),
              const SizedBox(height: 16),
              _saving
                  ? const CircularProgressIndicator()
                  : FilledButton(
                      onPressed: _submit,
                      child: const Text('Update Password'),
                    ),
            ],
          ),
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

  bool _hasUppercase(String s) => RegExp(r'[A-Z]').hasMatch(s);
  bool _hasLowercase(String s) => RegExp(r'[a-z]').hasMatch(s);
  bool _hasDigit(String s) => RegExp(r'[0-9]').hasMatch(s);
  bool _hasSpecial(String s) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(s);
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
                _RuleRow(label: 'Special character ( !@#\$%^&*(),.?":{}|<> )', ok: _hasSpecial(s)),
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
