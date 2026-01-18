import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '/services/misc/logger.dart';
import '/services/users/User.dart';
import '/main.dart' show supabaseUrl, supabaseKey;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class Authentication {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Hack Club OAuth configuration
  static String? _hackClubClientId;
  static String? _hackClubRedirectUri;
  static String? _hackClubState;

  /// Initialize Hack Club OAuth configuration
  static void configureHackClubOAuth({
    required String clientId,
    required String redirectUri,
  }) {
    _hackClubClientId = clientId;
    _hackClubRedirectUri = redirectUri;
  }

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

  /// Sign in with Hack Club OAuth
  /// Redirects to Hack Club authorization endpoint
  static Future<void> signInWithHackClub() async {
    if (_hackClubClientId == null || _hackClubRedirectUri == null) {
      throw AuthFailure(
        'Hack Club OAuth not configured. Call configureHackClubOAuth() first.',
      );
    }

    try {
      // Generate random state for CSRF protection
      _hackClubState = _generateRandomString(32);
      await _storage.write(key: 'hackclub_state', value: _hackClubState);

      // Build authorization URL
      final authUrl = Uri.parse('https://auth.hackclub.com/oauth/authorize')
          .replace(
            queryParameters: {
              'client_id': _hackClubClientId!,
              'redirect_uri': _hackClubRedirectUri!,
              'response_type': 'code',
              'scope': 'openid profile email slack_id verification_status',
              'state': _hackClubState!,
            },
          );

      AppLogger.info('Redirecting to Hack Club: ${authUrl.toString()}');

      // Launch browser for OAuth flow
      if (kIsWeb) {
        // On web, redirect current window
        await launchUrl(authUrl, webOnlyWindowName: '_self');
      } else {
        // On mobile/desktop, open external browser
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e, stack) {
      AppLogger.error('Hack Club OAuth redirect failed', e, stack);
      throw AuthFailure('Hack Club OAuth redirect failed: ${e.toString()}');
    }
  }

  /// Handle OAuth callback with authorization code
  /// Call this when redirected back from Hack Club
  static Future<void> handleHackClubCallback(Uri callbackUri) async {
    try {
      final code = callbackUri.queryParameters['code'];
      final state = callbackUri.queryParameters['state'];
      final error = callbackUri.queryParameters['error'];

      if (error != null) {
        throw AuthFailure('OAuth error: $error');
      }

      if (code == null) {
        throw AuthFailure('No authorization code received');
      }

      // Verify state to prevent CSRF
      final savedState = await _storage.read(key: 'hackclub_state');
      if (state != savedState) {
        throw AuthFailure('Invalid state parameter - possible CSRF attack');
      }

      await _storage.delete(key: 'hackclub_state');

      // Exchange code for Supabase session via edge function
      await _exchangeCodeForSession(code);
    } catch (e, stack) {
      AppLogger.error('Hack Club OAuth callback failed', e, stack);
      throw AuthFailure('Hack Club OAuth callback failed: ${e.toString()}');
    }
  }

  /// Exchange authorization code for Supabase session
  static Future<void> _exchangeCodeForSession(String code) async {
    final response = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/hackclub-login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseKey',
      },
      body: jsonEncode({'code': code, 'redirect_uri': _hackClubRedirectUri}),
    );

    if (response.statusCode != 200) {
      AppLogger.error('Token exchange failed: ${response.body}');
      throw AuthFailure('Failed to exchange code for session');
    }

    final data = jsonDecode(response.body);
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];

    if (accessToken == null || refreshToken == null) {
      throw AuthFailure('Invalid session data from server');
    }

    // Set the Supabase session
    await SupabaseAuth.supabase.auth.setSession(refreshToken);

    final supabaseUser = SupabaseAuth.supabase.auth.currentUser;
    if (supabaseUser != null) {
      await _storage.write(
        key: 'supabase_user',
        value: jsonEncode(supabaseUser.toJson()),
      );

      // Load the user record (edge function already created/updated it)
      final user = await UserService.getUserById(supabaseUser.id);
      if (user != null) {
        UserService.currentUser = user;
      } else {
        throw AuthFailure('User record not found after Hack Club login');
      }

      AppLogger.info('Successfully logged in with Hack Club');
    }
  }

  /// Generate random string for state parameter
  static String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      length,
      (index) => chars[(random + index) % chars.length],
    ).join();
  }

  static Future<void> signOut() async {
    try {
      await SupabaseAuth.signOut();
      await _storage.delete(key: 'supabase_session');
      await _storage.delete(key: 'supabase_user');
      await _storage.delete(key: 'hackclub_state');
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

      if (response.user == null) return false;

      // Try to get existing user, or create new one for OAuth users
      try {
        await UserService.setCurrentUser(response.user!.id);
      } catch (e) {
        // User doesn't exist - this is likely a new OAuth user
        // Initialize them in the database
        await UserService.initializeUser(
          id: response.user!.id,
          email: response.user!.email ?? '',
        );
      }

      return response.session != null;
    } catch (e, stack) {
      AppLogger.error('Error restoring saved session', e, stack);
      return false;
    }
  }
}
