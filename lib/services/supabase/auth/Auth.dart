import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '/services/misc/logger.dart';
import '/services/users/user.dart';

class Authentication {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static Future<void> signUp(String email, String password) async {
    try {
      AuthResponse session = await SupabaseAuth.signUp(email, password);
      if (session.session == null || session.user == null) {
        throw AuthFailure('Sign up failed: Session or user is null');
      }
      await _storage.write(
        key: 'supabase_session',
        value: jsonEncode(session.session?.toJson()),
      );
      await _storage.write(
        key: 'supabase_user',
        value: jsonEncode(session.user?.toJson()),
      );
      //Create user profile
      await UserService.initializeUser(
        id: session.user!.id,
        email: session.user!.email!,
      );
    } catch (e, stack) {
      AppLogger.error('Sign up failed for $email', e, stack);
      throw AuthFailure('Sign up failed: ${e.toString()}');
    }
  }

  static Future<void> signIn(String email, String password) async {
    try {
      AuthResponse session = await SupabaseAuth.signIn(email, password);
      if (session.session == null || session.user == null) {
        throw AuthFailure('Sign in failed: Session or user is null');
      }
      await _storage.write(
        key: 'supabase_session',
        value: jsonEncode(session.session?.toJson()),
      );
      await _storage.write(
        key: 'supabase_user',
        value: jsonEncode(session.user?.toJson()),
      );
      await UserService.setCurrentUser(session.user!.id);
    } catch (e, stack) {
      AppLogger.error('Sign in failed for $email', e, stack);
      throw AuthFailure('Sign in failed: ${e.toString()}');
    }
  }

  static Future<void> signInWithSlack() async {
    try {
      await SupabaseAuth.signInWithOAuth(OAuthProvider.slackOidc);
    } catch (e, stack) {
      AppLogger.error('OAuth sign in failed for slack', e, stack);
      throw AuthFailure('OAuth sign in failed: ${e.toString()}');
    }
  }

  static Future<void> signOut() async {
    try {
      await SupabaseAuth.signOut();
      await _storage.delete(key: 'supabase_session');
      await _storage.delete(key: 'supabase_user');
    } catch (e, stack) {
      AppLogger.error('Sign out failed', e, stack);
      throw AuthFailure('Sign out failed: ${e.toString()}');
    }
  }

  static Future<void> refreshSession(Session session) async {
    try {
      await _storage.write(
        key: 'supabase_session',
        value: jsonEncode(session.toJson()),
      );
    } catch (e, stack) {
      AppLogger.error('Session refresh failed', e, stack);
      throw AuthFailure('Session refresh failed: ${e.toString()}');
    }
  }

  static bool isLoggedIn() {
    final session = SupabaseAuth.supabase.auth.currentSession;

    if (session == null) return false;

    final expiry = DateTime.fromMillisecondsSinceEpoch(
      session.expiresAt! * 1000,
      isUtc: true,
    );
    return expiry.isAfter(DateTime.now().toUtc());
  }

  static Future<Session?> getSavedSession() async {
    try {
      String? sessionJson = await _storage.read(key: 'supabase_session');
      if (sessionJson != null) {
        Map<String, dynamic> sessionMap = jsonDecode(sessionJson);
        return Session.fromJson(sessionMap);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get saved session', e, stack);
      throw AuthFailure('Failed to get saved session: ${e.toString()}');
    }
  }

  static Future<User?> getSavedUser() async {
    try {
      String? userJson = await _storage.read(key: 'supabase_user');
      if (userJson != null) {
        Map<String, dynamic> userMap = jsonDecode(userJson);
        return User.fromJson(userMap);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to get saved user', e, stack);
      throw AuthFailure('Failed to get saved user: ${e.toString()}');
    }
  }

  static Future<bool> restoreStoredSession() async {
    try {
      String? sessionJson = await _storage.read(key: 'supabase_session');
      if (sessionJson == null) return false;

      // Restore session to Supabase
      AuthResponse response = await SupabaseAuth.supabase.auth.recoverSession(
        sessionJson,
      );
      await UserService.setCurrentUser(response.user!.id);
      return response.session != null;
    } catch (e, stack) {
      AppLogger.error('Error restoring saved session', e, stack);
      return false;
    }
  }
}
