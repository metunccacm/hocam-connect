import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signIn({required String email, required String password}) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        throw Exception('Login failed. Please check your credentials.');
      }
    } on AuthException catch (e) {
      // Re-throw the exception to be caught in the ViewModel
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
