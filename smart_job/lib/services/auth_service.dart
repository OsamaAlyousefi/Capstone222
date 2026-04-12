import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AuthService {
  static Future<AuthResponse> signUp(String email, String password) async {
    return await supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  static User? get currentUser => supabase.auth.currentUser;

  static String? get accessToken => supabase.auth.currentSession?.accessToken;

  static bool get isLoggedIn => supabase.auth.currentUser != null;

  static Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }
}
