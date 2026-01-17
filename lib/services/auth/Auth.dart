import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'supabase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '/services/misc/logger.dart';
import '/services/users/User.dart';
import '/main.dart' show supabaseUrl, supabaseKey;

class Authentication {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static OidcUserManager? _hackClubManager;

  static Future<void> initHackClubOidc({
    required String clientId,
    required String clientSecret,
    required Uri redirectUri,
    Uri? postLogoutRedirectUri,
    List<String> scopes = const [
      'openid',
      'profile',
      'email',
      'name',
      'slack_id',
      'verification_status',
    ],
  }) async {
    _hackClubManager = OidcUserManager.lazy(
      discoveryDocumentUri: Uri.parse(
        'https://auth.hackclub.com/.well-known/openid-configuration',
      ),
      clientCredentials: OidcClientAuthentication.clientSecretPost(
        clientId: clientId,
        clientSecret: clientSecret,
      ),
      store: OidcDefaultStore(),
      settings: OidcUserManagerSettings(
        redirectUri: redirectUri,
        postLogoutRedirectUri: postLogoutRedirectUri,
        scope: scopes,

        refreshBefore: (token) => null,
      ),
    );
    await _hackClubManager!.init();
  }

  /// Get the current Hack Club OIDC user
  static OidcUser? get hackClubUser => _hackClubManager?.currentUser;

  /// Stream of Hack Club user changes
  static Stream<OidcUser?>? hackClubUserChanges() =>
      _hackClubManager?.userChanges();

  /// Get the current Hack Club access token
  static String? get hackClubAccessToken =>
      _hackClubManager?.currentUser?.token.accessToken;

  /// Get the current Hack Club ID token
  static String? get hackClubIdToken => _hackClubManager?.currentUser?.idToken;

  /// Get claims from the Hack Club ID token
  static Map<String, dynamic>? get hackClubClaims =>
      _hackClubManager?.currentUser?.aggregatedClaims;

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

  /// Sign in with Hack Club OIDC and exchange for Supabase session
  /// Make sure to call initHackClubOidc() first
  static Future<OidcUser?> signInWithHackClub({
    List<String>? promptOverride,
    Duration? maxAgeOverride,
    Map<String, dynamic>? extraParameters,
  }) async {
    if (_hackClubManager == null) {
      throw AuthFailure(
        'Hack Club OIDC not initialized. Call initHackClubOidc() first.',
      );
    }
    try {
      final user = await _hackClubManager!.loginAuthorizationCodeFlow(
        promptOverride: promptOverride,
        maxAgeOverride: maxAgeOverride,
        extraParameters: extraParameters,
      );

      if (user != null) {
        // Exchange Hack Club token for Supabase session
        await _exchangeHackClubTokenForSupabase(user);
      }
      return user;
    } catch (e, stack) {
      AppLogger.error('Hack Club OIDC sign in failed', e, stack);
      throw AuthFailure('Hack Club OIDC sign in failed: ${e.toString()}');
    }
  }

  /// Exchange Hack Club access token for a Supabase session
  static Future<void> _exchangeHackClubTokenForSupabase(
    OidcUser hackClubUser,
  ) async {
    final accessToken = hackClubUser.token.accessToken;
    if (accessToken == null) {
      throw AuthFailure('No Hack Club access token available');
    }

    final response = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/hackclub-auth'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseKey',
      },
      body: jsonEncode({'access_token': accessToken}),
    );

    if (response.statusCode != 200) {
      AppLogger.error('Failed to exchange Hack Club token: ${response.body}');
      throw AuthFailure(
        'Failed to exchange Hack Club token for Supabase session',
      );
    }

    final data = jsonDecode(response.body);
    final sessionData = data['session'];

    if (sessionData == null) {
      throw AuthFailure('No session returned from token exchange');
    }

    // Set the Supabase session
    final session = Session.fromJson(sessionData);
    final refreshToken = session?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw AuthFailure('No refresh token in session');
    }
    await SupabaseAuth.supabase.auth.setSession(refreshToken);

    // Store session locally
    await _storage.write(
      key: 'supabase_session',
      value: jsonEncode(session?.toJson()),
    );

    final supabaseUser = SupabaseAuth.supabase.auth.currentUser;
    if (supabaseUser != null) {
      await _storage.write(
        key: 'supabase_user',
        value: jsonEncode(supabaseUser.toJson()),
      );

      // Set current user from Supabase (now using proper UUID)
      try {
        await UserService.setCurrentUser(
          supabaseUser.id,
          email: supabaseUser.email,
        );
      } catch (e) {
        // User will be created by the edge function, just fetch them
        await Future.delayed(const Duration(milliseconds: 200));
        await UserService.setCurrentUser(
          supabaseUser.id,
          email: supabaseUser.email,
        );
      }
    }

    AppLogger.info(
      'Successfully exchanged Hack Club token for Supabase session',
    );
  }

  /// Force re-authentication with Hack Club (for sensitive operations)
  static Future<OidcUser?> reauthenticateWithHackClub() async {
    return signInWithHackClub(promptOverride: ['login']);
  }

  static Future<void> signOut() async {
    try {
      await SupabaseAuth.signOut();
      await _storage.delete(key: 'supabase_session');
      await _storage.delete(key: 'supabase_user');
      // Also sign out from Hack Club OIDC if initialized
      await signOutHackClub();
    } catch (e, stack) {
      AppLogger.error('Sign out failed', e, stack);
      throw AuthFailure('Sign out failed: ${e.toString()}');
    }
  }

  /// Sign out from Hack Club OIDC only
  /// Use forgetOnly: true to just clear local state without notifying the provider
  static Future<void> signOutHackClub({bool forgetOnly = false}) async {
    if (_hackClubManager == null) return;
    try {
      if (forgetOnly) {
        await _hackClubManager!.forgetUser();
      } else {
        await _hackClubManager!.logout();
      }
    } catch (e, stack) {
      AppLogger.error('Hack Club OIDC sign out failed', e, stack);
      // Don't rethrow - sign out should be best effort
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

  /// Check if logged in with Hack Club OIDC
  static bool isHackClubLoggedIn() {
    return _hackClubManager?.currentUser != null;
  }

  /// Check if logged in with either Supabase or Hack Club
  static bool isAnyLoggedIn() {
    return isLoggedIn() || isHackClubLoggedIn();
  }

  /// Refresh the Hack Club OIDC token manually
  static Future<OidcUser?> refreshHackClubToken() async {
    if (_hackClubManager == null) return null;
    try {
      return await _hackClubManager!.refreshToken();
    } catch (e, stack) {
      AppLogger.error('Hack Club token refresh failed', e, stack);
      return null;
    }
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
