import 'supabase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth.dart';
import 'dart:async';

class AuthListener {
  static StreamSubscription<AuthState>? _authSubscription;

  static void startListening() {
    _authSubscription = SupabaseAuth.supabase.auth.onAuthStateChange.listen((
      authState,
    ) {
      final event = authState.event;
      final session = authState.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          // User signed in
          break;

        case AuthChangeEvent.tokenRefreshed:
          if (session != null) {
            Authentication.refreshSession(session);
          }
          break;

        case AuthChangeEvent.signedOut:
          // User signed out or session expired
          break;
        default:
          // Unknown auth event
          break;
      }
    });
  }

  static void dispose() {
    _authSubscription?.cancel();
  }
}
