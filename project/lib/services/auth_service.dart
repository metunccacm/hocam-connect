import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Login
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth
        .signInWithPassword(email: email, password: password);
  }

  // Register
  Future<AuthResponse> signUp(String email, String password,
      {Map<String, dynamic>? data}) async {
    return await _client.auth
        .signUp(email: email, password: password, data: data);
  }

  //Log out
  Future<void> signOut() async {
    // Clear FCM token from Supabase before signing out
    await NotificationService().deleteTokenFromSupabase();
    await _client.auth.signOut();
  }

  // Oturum açıkken metadata güncelleme (fallback)
  Future<void> updateMetadata(Map<String, dynamic> data) async {
    await _client.auth.updateUser(UserAttributes(data: data));
  }

  //Get name of the user to display
  // Future<String?> getUserName() async {
  //   final user = _client.auth.currentUser;
  //   return user?.name;
  // }
}
