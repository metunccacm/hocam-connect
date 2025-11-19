// lib/viewmodel/register_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    // DOB -> ISO
    String? dobIso;
    if (dobText != null && dobText.trim().isNotEmpty) {
      try {
        final parsed = DateFormat('dd/MM/yyyy').parseStrict(dobText.trim());
        dobIso = DateFormat('yyyy-MM-dd').format(parsed);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid date format. Use dd/MM/yyyy')),
          );
        }
        isLoading = false;
        notifyListeners();
        return;
      }
    }

    final first = name.trim();
    final last = surname.trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');

    // 1) AUTH metadata (opsiyonel ama güzel)
    final meta = <String, dynamic>{
      if (full.isNotEmpty) 'full_name': full,
      if (first.isNotEmpty) 'name': first,
      if (last.isNotEmpty) 'surname': last,
      if (dobIso != null) 'dob': dobIso,
    };

    try {
      // Kayıt: signUp sonucu user döndürür ama çoğu projede session dönmez (email confirm açıkken)
      final signUpRes = await _auth.signUp(email.trim(), password, data: meta);

      final uid = signUpRes.user?.id;
      if (uid == null) {
        // Çok nadir: user null dönerse
        throw AuthException('User id missing after signUp.');
      }

      // 2) profiles'a kesin yaz: upsert (id konfliktta update)
      try {
        final payload = <String, dynamic>{
          'id': uid, // kritik: insert için id şart
          if (first.isNotEmpty) 'name': first,
          if (last.isNotEmpty) 'surname': last,
          if (dobIso != null) 'dob': dobIso, // kolonu DATE ise doğrudan yaz
        };

        await Supabase.instance.client
            .from('profiles')
            .upsert(payload, onConflict: 'id') // <— ana fark
            .select()
            .single();
      } on PostgrestException catch (e) {
        debugPrint(
            'PG ERROR code=${e.code} message=${e.message} details=${e.details}');
        // İstersen kullanıcıya da göster:
        // if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }

      // (İsteğe bağlı) Auth metadata’yı güncelle: email confirm'den sonra da eşit kalsın
      try {
        await Supabase.instance.client.auth
            .updateUser(UserAttributes(data: meta));
      } catch (_) {
        // Sessiz geç; önemli olan profiles upsert'ı
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
            const SnackBar(
              content: Text('Check your email to confirm your account.'),
            ),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        }
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
