import 'package:universal_html/html.dart' as html;
import 'package:boot_app/services/misc/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Auth.dart';

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

  static Future<void> signInWithOAuth(OAuthProvider provider) async {
    try {
      // Ensure redirect goes back to the same origin/path so PKCE verifier matches
      final base = Uri.base;
      final cleanRedirect = Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: base.path,
      ).toString();
      await supabase.auth.signInWithOAuth(provider, redirectTo: cleanRedirect);
    } on AuthException catch (e) {
      AppLogger.warning('Supabase OAuth sign in failed: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during Supabase OAuth sign in',
        e,
        stack,
      );
      throw AuthFailure(
        'Unexpected error during OAuth sign in. Please try again.',
      );
    }
  }

  static Future<void> redirectCheck() async {
    final uri = Uri.base; // current URL
    if (uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token')) {
      try {
        // Only attempt exchange if we don't already have a session
        if (Supabase.instance.client.auth.currentSession == null) {
          await Supabase.instance.client.auth.getSessionFromUrl(
            uri,
            storeSession: true,
          );
        }

        // Persist session so app routing that relies on storage works
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          await Authentication.refreshSession(session);
        }
        final redirectUri = Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
          path: uri.path,
        );

        try {
          html.window.history.replaceState(
            null,
            'Auth',
            redirectUri.toString(),
          );
          // Navigate to the cleaned URL so the app can pick up the new session
          try {
            html.window.location.replace(redirectUri.toString());
          } catch (_) {
            // fallback to reload if replace is not allowed
            try {
              html.window.location.reload();
            } catch (_) {}
          }
        } catch (_) {
          // ignore if not running on web
        }
      } catch (e) {
        AppLogger.warning('OAuth sign-in error: $e');
      }
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
