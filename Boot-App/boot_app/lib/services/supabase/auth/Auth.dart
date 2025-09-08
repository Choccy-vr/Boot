import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '/services/users/User.dart';

class Authentication {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final List<String> errorLog = [];

  static Future<void> clearStoredSession() async {
    await _storage.delete(key: 'supabase_session');
    await _storage.delete(key: 'supabase_user');
  }

  static Future<void> SignUp(String email, String password) async {
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
      await UserService.initializeUser(
        id: session.user!.id,
        email: session.user!.email!,
      );
    } catch (e) {
      errorLog.add('SignUp: ${e.toString()}');
      throw AuthFailure('Sign up failed: ${e.toString()}');
    }
  }

  static Future<void> SignIn(String email, String password) async {
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
    } catch (e) {
      errorLog.add('SignIn: ${e.toString()}');
      throw AuthFailure('Sign in failed: ${e.toString()}');
    }
  }

  static Future<void> SignOut() async {
    try {
      await SupabaseAuth.signOut();
      await _storage.delete(key: 'supabase_session');
      await _storage.delete(key: 'supabase_user');
    } catch (e) {
      errorLog.add('SignOut: ${e.toString()}');
      throw AuthFailure('Sign out failed: ${e.toString()}');
    }
  }

  static Future<void> RefreshSession(Session session) async {
    try {
      await _storage.write(
        key: 'supabase_session',
        value: jsonEncode(session.toJson()),
      );
    } catch (e) {
      errorLog.add('Refresh: ${e.toString()}');
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
    } catch (e) {
      errorLog.add('GetSavedSession: ${e.toString()}');
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
    } catch (e) {
      errorLog.add('GetSavedUser: ${e.toString()}');
      throw AuthFailure('Failed to get saved user: ${e.toString()}');
    }
  }

  static Future<bool> restoreStoredSession() async {
    const tag = '[AuthRestore]';
    try {
      final sessionJson = await _storage.read(key: 'supabase_session');
      if (sessionJson == null) {
        print('$tag No stored session');
        return false;
      }
      try {
        final temp = jsonDecode(sessionJson);
        final expiresAt = temp['expires_at'];
        if (expiresAt is int) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(
            expiresAt * 1000,
            isUtc: true,
          );
          if (expiry.isBefore(DateTime.now().toUtc())) {
            print('$tag Stored session expired. Clearing.');
            await clearStoredSession();
            return false;
          }
        }
      } catch (_) {}

      final response = await SupabaseAuth.supabase.auth.recoverSession(
        sessionJson,
      );
      if (response.session == null || response.user == null) {
        print('$tag Null session/user. Clearing.');
        await clearStoredSession();
        return false;
      }
      await UserService.setCurrentUser(response.user!.id);
      print('$tag Restored for user ${response.user!.id}');
      return true;
    } on AuthException catch (ae) {
      final lower = ae.message.toLowerCase();
      if (lower.contains('refresh token') || lower.contains('refresh_token')) {
        print('$tag Invalid refresh token. Clearing.');
        await clearStoredSession();
        return false;
      }
      print('$tag AuthException ${ae.message}');
      errorLog.add('Restore AuthException: ${ae.message}');
      return false;
    } catch (e) {
      print('$tag Unexpected error $e');
      errorLog.add('Restore Unexpected: $e');
      return false;
    }
  }
}
