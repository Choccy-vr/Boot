import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/auth/supabase_auth.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/services/notifications/notifications.dart';

class HackatimeService {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final SupabaseClient _supabase = Supabase.instance.client;
  static String? _accessToken;
  static String _tokenType = 'Bearer';
  static const String _stateStorageKey = 'hackatime_state';
  static const String _pkceVerifierStorageKey = 'hackatime_pkce_code_verifier';
  static const String _tokenExpiryStorageKey = 'hackatime_token_expiry';

  /// Fast synchronous hint used by routing guards while async restore catches up.
  static bool get hasCachedAccessToken =>
      _accessToken != null && _accessToken!.isNotEmpty;

  // Hackatime OAuth configuration
  static String? _hackatimeClientId;
  static String? _hackatimeRedirectUri;
  static String? _hackatimeState;

  /// Initialize Hackatime OAuth configuration
  static void configureHackatimeOAuth({
    required String clientId,
    required String redirectUri,
  }) {
    _hackatimeClientId = clientId;
    _hackatimeRedirectUri = redirectUri;
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

  static String _generateCodeVerifier([int length = 64]) {
    if (length < 43 || length > 128) {
      throw ArgumentError('PKCE code_verifier length must be 43-128 chars.');
    }

    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  static String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static Future<void> _saveOAuthToken(
    Map<String, dynamic> tokenResponse,
  ) async {
    final accessToken = tokenResponse['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw AuthFailure(
        'Hackatime token response did not include access_token.',
      );
    }

    final tokenType = tokenResponse['token_type']?.toString() ?? 'Bearer';
    _accessToken = accessToken;
    _tokenType = tokenType;
  }

  static Future<bool> _hasServerStoredToken() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final row = await _supabase
          .from('users')
          .select('hackatime_access_token')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (row == null) return false;

      final stored = row['hackatime_access_token']?.toString().trim() ?? '';
      return stored.isNotEmpty;
    } catch (e, stack) {
      AppLogger.error(
        'Failed checking Hackatime token presence in users row',
        e,
        stack,
      );
      return false;
    }
  }

  static Future<bool> _tryRestoreTokenFromEdge() async {
    try {
      final response = await _supabase.functions.invoke(
        'hackatime_auth',
        body: <String, dynamic>{'mode': 'restore'},
      );

      if (response.status < 200 || response.status >= 300) {
        return false;
      }

      final decoded = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final accessToken = decoded['access_token']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      await _saveOAuthToken(decoded);
      AppLogger.info('Restored Hackatime OAuth token from server user row.');
      return true;
    } catch (e, stack) {
      AppLogger.warning('Failed to restore Hackatime token from server: $e');
      AppLogger.error('Hackatime server restore error details', e, stack);
      return false;
    }
  }

  /// Returns null when missing
  static Future<String?> getStoredAccessToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return _accessToken;
    }

    final restored = await _tryRestoreTokenFromEdge();
    if (!restored) {
      return null;
    }
    return _accessToken;
  }

  static Future<Map<String, String>?> getAuthorizationHeaders() async {
    final accessToken = await getStoredAccessToken();
    if (accessToken == null) {
      return null;
    }

    return {'Authorization': '$_tokenType $accessToken'};
  }

  static Future<bool> isAuthenticated() async {
    final accessToken = await getStoredAccessToken();
    if (accessToken != null) return true;

    return _hasServerStoredToken();
  }

  static Future<void> clearStoredAuth() async {
    _accessToken = null;
    _tokenType = 'Bearer';
    await _storage.delete(key: _tokenExpiryStorageKey);
    await _storage.delete(key: _pkceVerifierStorageKey);
  }

  /// Sign in with Hackatime OAuth
  /// Redirects to Hackatime authorization endpoint
  static Future<void> signInWithHackatime() async {
    final existingAccessToken = _accessToken;
    if (existingAccessToken != null && existingAccessToken.isNotEmpty) {
      return;
    }

    final hasServerToken = await _hasServerStoredToken();
    if (hasServerToken) {
      final restoredFromServer = await _tryRestoreTokenFromEdge();
      if (restoredFromServer) {
        return;
      }

      throw AuthFailure(
        'Hackatime token exists in users row but could not be restored from edge function.',
      );
    }

    if (_hackatimeClientId == null || _hackatimeRedirectUri == null) {
      throw AuthFailure(
        'Hackatime OAuth not configured. Call configureHackatimeOAuth() first.',
      );
    }

    try {
      // Generate random state for CSRF protection
      _hackatimeState = _generateRandomString(32);
      await _storage.write(key: _stateStorageKey, value: _hackatimeState);

      // Generate and persist PKCE verifier for token exchange callback
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      await _storage.write(key: _pkceVerifierStorageKey, value: codeVerifier);

      // Build authorization URL
      final authUrl =
          Uri.parse('https://hackatime.hackclub.com/oauth/authorize').replace(
            queryParameters: {
              'client_id': _hackatimeClientId!,
              'redirect_uri': _hackatimeRedirectUri!,
              'response_type': 'code',
              'scope': 'profile read',
              'state': _hackatimeState!,
              'code_challenge': codeChallenge,
              'code_challenge_method': 'S256',
            },
          );

      AppLogger.info('Redirecting to Hackatime OAuth: ${authUrl.toString()}');

      // Launch browser for OAuth flow
      await launchUrl(authUrl, webOnlyWindowName: '_self');
    } catch (e, stack) {
      AppLogger.error('Hackatime OAuth redirect failed', e, stack);
      throw AuthFailure('Hackatime OAuth redirect failed: ${e.toString()}');
    }
  }

  /// Returns true when the callback state matches a pending Hackatime OAuth flow.
  static Future<bool> hasPendingOAuthState(String? callbackState) async {
    if (callbackState == null || callbackState.isEmpty) {
      return false;
    }

    final savedState = await _storage.read(key: _stateStorageKey);
    return savedState != null && savedState == callbackState;
  }

  /// Handle OAuth callback with authorization code and persist the token.
  static Future<void> handleHackatimeCallback(Uri callbackUri) async {
    final code = callbackUri.queryParameters['code'];
    final state = callbackUri.queryParameters['state'];
    final error = callbackUri.queryParameters['error'];

    if (error != null) {
      throw AuthFailure('Hackatime OAuth error: $error');
    }

    if (code == null || code.isEmpty) {
      throw AuthFailure('No Hackatime authorization code received.');
    }

    final savedState = await _storage.read(key: _stateStorageKey);
    if (savedState == null || savedState.isEmpty || state != savedState) {
      throw AuthFailure(
        'Invalid Hackatime state parameter - possible CSRF attack.',
      );
    }

    await _storage.delete(key: _stateStorageKey);
    await exchangeCodeForToken(code: code);
    AppLogger.info('Successfully authenticated with Hackatime OAuth');
  }

  /// Exchange authorization code for tokens using PKCE verifier.
  static Future<Map<String, dynamic>> exchangeCodeForToken({
    required String code,
  }) async {
    if (_hackatimeClientId == null || _hackatimeRedirectUri == null) {
      throw AuthFailure(
        'Hackatime OAuth not configured. Call configureHackatimeOAuth() first.',
      );
    }

    final codeVerifier = await _storage.read(key: _pkceVerifierStorageKey);
    if (codeVerifier == null || codeVerifier.isEmpty) {
      throw AuthFailure('Missing PKCE code_verifier. Start OAuth flow again.');
    }

    try {
      final response = await _supabase.functions.invoke(
        'hackatime_auth',
        body: {
          'client_id': _hackatimeClientId!,
          'code': code,
          'redirect_uri': _hackatimeRedirectUri!,
          'code_verifier': codeVerifier,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        final responseBody = response.data;
        final responseDetails = responseBody is Map<String, dynamic>
            ? jsonEncode(responseBody)
            : responseBody?.toString() ?? '<empty>';

        AppLogger.warning(
          'Hackatime token exchange failed with status ${response.status}: $responseDetails',
        );
        throw AuthFailure(
          'Hackatime token exchange failed (status: ${response.status}).',
        );
      }

      final decoded = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      await _saveOAuthToken(decoded);

      await _storage.delete(key: _pkceVerifierStorageKey);

      return decoded;
    } catch (e, stack) {
      AppLogger.error('Hackatime token exchange failed', e, stack);
      rethrow;
    }
  }

  static String _getErrorMessage(int statusCode, String defaultMessage) {
    if (statusCode == 403 || statusCode == 404) {
      return 'Hackatime is most likely down or unavailable (Error: $defaultMessage Status: $statusCode)';
    }
    return '$defaultMessage (Status: $statusCode)';
  }

  static Future<List<HackatimeProject>> fetchHackatimeProjects({
    BuildContext? context,
  }) async {
    final authorizationHeaders = await getAuthorizationHeaders();
    if (authorizationHeaders == null) {
      AppLogger.warning(
        'Cannot fetch Hackatime projects: No access token available. Please authenticate first.',
      );
      return [];
    }

    try {
      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/authenticated/projects',
      );
      final response = await http.get(url, headers: authorizationHeaders);
      if (response.statusCode == 200) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        final List<dynamic> projects =
            decoded['projects'] ?? decoded['data']?['projects'] ?? [];
        return projects.map((project) {
          return HackatimeProject.fromJson(project);
        }).toList();
      }

      AppLogger.warning(
        'Hackatime project fetch failed for user with status ${response.statusCode}: ${response.body}.',
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => GlobalNotificationService.instance.showError(
          'Hackatime Error: ${_getErrorMessage(response.statusCode, 'Failed to load projects')}',
        ),
      );

      return [];
    } catch (e, stack) {
      AppLogger.error('Network error loading Hackatime projects', e, stack);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => GlobalNotificationService.instance.showError(
          'Hackatime Error: Network error loading projects',
        ),
      );
      return [];
    }
  }

  static Future<bool> isHackatimeBanned({BuildContext? context}) async {
    final authorizationHeaders = await getAuthorizationHeaders();
    if (authorizationHeaders == null) {
      AppLogger.warning(
        'Hackatime ban check skipped: No access token available. Please authenticate first.',
      );
      return true;
    }

    try {
      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/authenticated/me',
      );

      final response = await http.get(url, headers: authorizationHeaders);
      if (response.statusCode == 200) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        final String? trustLevel = decoded['data']?['trust_level'];
        if (trustLevel == 'red') return true;
        return false;
      }

      AppLogger.warning(
        'Hackatime ban check failed for user with status ${response.statusCode}: ${response.body}.',
      );

      return true;
    } catch (e, stack) {
      AppLogger.error(
        'Network error checking Hackatime ban status for user',
        e,
        stack,
      );
      return true;
    }
  }

  static Future<bool> canReachHackatime() async {
    try {
      final authorizationHeaders = await getAuthorizationHeaders();
      if (authorizationHeaders == null) {
        AppLogger.warning(
          'Hackatime reachability check skipped: No access token available. Please authenticate first.',
        );
        return false;
      }

      final url = Uri.parse(
        'https://hackatime.hackclub.com/api/v1/authenticated/me',
      );
      final response = await http
          .get(url, headers: authorizationHeaders)
          .timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e, stack) {
      AppLogger.error(
        'Network error checking Hackatime reachability for user',
        e,
        stack,
      );
      return false;
    }
  }

  static Future<Project> getProjectTime({
    required Project project,
    BuildContext? context,
  }) async {
    try {
      final projects = await fetchHackatimeProjects(context: context);
      if (projects.isEmpty) {
        AppLogger.warning('Hackatime projects list empty for user');
      }
      if (project.hackatimeProjects.isEmpty) {
        project.time = 0;
        project.readableTime = '0m';
        return project;
      }

      int totalSeconds = 0;
      final missingProjects = <String>[];
      for (final projectName in project.hackatimeProjects) {
        final details = _findProjectByName(projects, projectName);
        if (details == null) {
          missingProjects.add(projectName);
          continue;
        }
        totalSeconds += details.totalSeconds;
      }

      if (missingProjects.isNotEmpty) {
        final missingList = missingProjects.join(', ');
        AppLogger.warning(
          'Hackatime project(s) $missingList not found for user',
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => GlobalNotificationService.instance.showError(
            'Hackatime Error: Project(s) $missingList not found on Hackatime',
          ),
        );
      }

      project.time = totalSeconds / 3600.0;
      project.readableTime = _formatReadableDuration(totalSeconds);
      return project;
    } catch (e, stack) {
      AppLogger.error(
        'Error fetching Hackatime project time for ${project.id} (${project.hackatimeProjects})',
        e,
        stack,
      );
      throw Exception('Error fetching project time: $e');
    }
  }

  static HackatimeProject? _findProjectByName(
    List<HackatimeProject> projects,
    String projectName,
  ) {
    try {
      return projects.firstWhere(
        (p) => p.name.toLowerCase() == projectName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatReadableDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }
}

class HackatimeProject {
  final String name;
  final int totalSeconds;
  final String text;
  final int hours;
  final int minutes;
  final String digital;

  HackatimeProject({
    required this.name,
    required this.totalSeconds,
    required this.text,
    required this.hours,
    required this.minutes,
    required this.digital,
  });

  factory HackatimeProject.fromJson(Map<String, dynamic> json) {
    final totalSeconds = json['total_seconds'] is int
        ? json['total_seconds']
        : int.tryParse(json['total_seconds'].toString()) ?? 0;
    final duration = Duration(seconds: totalSeconds);
    final derivedHours = duration.inHours;
    final derivedMinutes = duration.inMinutes.remainder(60);
    final derivedDigital =
        '${derivedHours.toString().padLeft(2, '0')}:${derivedMinutes.toString().padLeft(2, '0')}';
    final derivedText = derivedHours > 0
        ? '$derivedHours h ${derivedMinutes} m'
        : '$derivedMinutes m';

    return HackatimeProject(
      name: json['name'].toString(),
      totalSeconds: totalSeconds,
      text: (json['text']?.toString().isNotEmpty ?? false)
          ? json['text'].toString()
          : derivedText,
      hours: json['hours'] is int
          ? json['hours']
          : int.tryParse(json['hours'].toString()) ?? derivedHours,
      minutes: json['minutes'] is int
          ? json['minutes']
          : int.tryParse(json['minutes'].toString()) ?? derivedMinutes,
      digital: (json['digital']?.toString().isNotEmpty ?? false)
          ? json['digital'].toString()
          : derivedDigital,
    );
  }
}
