import 'package:boot_app/services/misc/logger.dart';
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
      AppLogger.warning('Supabase sign up failed: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e, stack) {
      AppLogger.error('Unexpected error during Supabase sign up', e, stack);
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
      AppLogger.warning('Supabase sign in failed: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e, stack) {
      AppLogger.error('Unexpected error during Supabase sign in', e, stack);
      throw AuthFailure('Unexpected error during sign in. Please try again.');
    }
  }

  static Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (e) {
      AppLogger.warning('Supabase sign out failed: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e, stack) {
      AppLogger.error('Unexpected error during Supabase sign out', e, stack);
      throw AuthFailure('Unexpected error during sign out. Please try again.');
    }
  }

  static Future<AuthResponse> refreshSession() async {
    try {
      return await supabase.auth.refreshSession();
    } on AuthException catch (e) {
      AppLogger.warning('Supabase session refresh failed: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during Supabase session refresh',
        e,
        stack,
      );
      throw AuthFailure(
        'Unexpected error during session refresh. Please try again.',
      );
    }
  }
}
