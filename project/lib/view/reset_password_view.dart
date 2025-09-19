import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String? _validatePass(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(s)) return 'At least one uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(s)) return 'At least one lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(s)) return 'At least one number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(s)) {
      return 'At least one special character';
    }
    return null;
  }

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
      await Supabase.instance.client.auth.signOut();

      // Navigate user back to your sign-in or root.
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
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _pass,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: _validatePass,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
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
