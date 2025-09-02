// lib/viewmodel/register_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// hata ayıklama için
import 'package:project/services/auth_service.dart';

class RegistrationViewModel extends ChangeNotifier {
  final AuthService _auth = AuthService();
  bool isLoading = false;

  /// UI tarafı formu doğruluyor; burası sadece iş yapıyor.
  /// DOB: 'dd/MM/yyyy' formatı beklenir; boş/geçersiz ise atlanır.
  Future<void> register(
    BuildContext context, {
    required String name,
    required String surname,
    required String email,
    required String password,
    String? dobText,
  }) async {
    isLoading = true;
    notifyListeners();

    // DOB -> ISO (Bu verileri ayrı tabloda tutmamız için)
    String? dobIso;
    if (dobText != null && dobText.trim().isNotEmpty) {
      try {
        final parsed = DateFormat('dd/MM/yyyy').parseStrict(dobText.trim());
        dobIso = DateFormat('yyyy-MM-dd').format(parsed);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid date format. Use dd/MM/yyyy')),
          );
        }
        isLoading = false;
        notifyListeners();
        return;
      }
    }

    final first = name.trim();
    final last  = surname.trim();
    final full  = [first, last].where((s) => s.isNotEmpty).join(' ');

    // 1) Kayıtta AUTH metadata gönder (Supabase "Display name" için)
    final meta = <String, dynamic>{
      if (full.isNotEmpty)  'full_name': full,
      if (first.isNotEmpty) 'name': first,
      if (last.isNotEmpty)  'surname': last,
      if (dobIso != null)   'dob': dobIso,
    };

    try {
      await _auth.signUp(email.trim(), password, data: meta);

      // 2) Session varsa profiles'ı GÜNCELLE
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({
                if (first.isNotEmpty) 'name': first,
                if (last.isNotEmpty)  'surname': last,
                if (dobIso != null)   'dob': dobIso,
              })
              .eq('id', user.id)
              .select()
              .single();
        } on PostgrestException catch (e) {
          debugPrint('PG ERROR code=${e.code} message=${e.message} details=${e.details}');
          // Database exception user debug:
          // if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }

      // 3) Yönlendirme / bilgilendirme
      final hasSession = Supabase.instance.client.auth.currentSession != null;
      if (hasSession) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Check your email to confirm your account.')),
          );
        }
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
