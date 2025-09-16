import 'supabase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Auth.dart';
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
          print('User signed in');
          break;

        case AuthChangeEvent.tokenRefreshed:
          if (session != null) {
            Authentication.RefreshSession(session);
          }
          break;

        case AuthChangeEvent.signedOut:
          print('User signed out or session expired');
          break;
        default:
          print('Unknown auth event');
          break;
      }
    });
  }

  static void dispose() {
    _authSubscription?.cancel();
  }
}
