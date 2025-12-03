// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project/view/reset_password_view.dart';

class RecoveryCodeView extends StatefulWidget {
  const RecoveryCodeView({
    super.key,
    this.prefillEmail,
    this.resetRedirectUrl = 'https://callback.hocamconnect.com.tr/reset',
  });

  final String? prefillEmail;
  final String resetRedirectUrl; // used if you add "Resend code"

  @override
  State<RecoveryCodeView> createState() => _RecoveryCodeViewState();
}

class _RecoveryCodeViewState extends State<RecoveryCodeView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _verifying = false;

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email';
    return null;
  }

  String? _validateCode(String? v) {
    final s = v?.trim() ?? '';
    if (s.length != 6) return 'Enter 6 digits';
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'Digits only';
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) {
      _emailCtrl.text = widget.prefillEmail!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _verifying = true);
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
      if (res.session == null) {
        throw const AuthException('Verification failed. Try again.');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResetPasswordView()),
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify the code.')),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Recovery Code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@domain.com',
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  hintText: '123456',
                ),
                validator: _validateCode,
              ),
              const SizedBox(height: 16),
              _verifying
                  ? const CircularProgressIndicator()
                  : FilledButton(
                      onPressed: _verify,
                      child: const Text('Verify Code'),
                    ),
              const SizedBox(height: 8),
              // Optional: a small "Resend" action using the same redirect URL
              TextButton(
                onPressed: () async {
                  if (_emailCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter your email first.')),
                    );
                    return;
                  }
                  try {
                    await Supabase.instance.client.auth.resetPasswordForEmail(
                      _emailCtrl.text.trim(),
                      redirectTo: widget.resetRedirectUrl,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code/link resent.')),
                    );
                  } catch (_) {}
                },
                child: const Text('Resend code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
