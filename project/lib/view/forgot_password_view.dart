import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:project/view/recovery_code_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
        redirectTo: 'https://callback.hocamconnect.com.tr/reset',
      );

      if (!mounted) return;
      
      final email = _emailCtrl.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset link sent. Enter the code to continue.')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
        builder: (_) => RecoveryCodeView(prefillEmail: email),
        ),
      );

    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || !EmailValidator.validate(v.trim()))
                          ? 'Please enter a valid email.'
                          : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: _sending
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _sendResetEmail,
                          child: const Text('Send reset link'),
                        ),
                ),
                TextButton(
                  onPressed: () {
                    final email = _emailCtrl.text.trim(); // from your forgot view
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecoveryCodeView(prefillEmail: email),
                      ),
                    );
                  },
                  child: const Text('Have a code? Enter it here'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
