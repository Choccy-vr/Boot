import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}

class SupabaseAuth {
  static final supabase = Supabase.instance.client;

  static Future<AuthResponse> signUp(String email, String password) async {
    try {
      return await supabase.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('Unexpected error during sign up. Please try again.');
    }
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('Unexpected error during sign in. Please try again.');
    }
  }

  static Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('Unexpected error during sign out. Please try again.');
    }
  }

  static Future<AuthResponse> refreshSession() async {
    try {
      return await supabase.auth.refreshSession();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure(
        'Unexpected error during session refresh. Please try again.',
      );
    }
  }
}



