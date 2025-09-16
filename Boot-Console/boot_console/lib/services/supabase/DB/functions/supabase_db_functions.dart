import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDB {
  static final supabase = Supabase.instance.client;

  static Future<void> CallDBFunction({
    required String functionName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      if (parameters == null) {
        await supabase.rpc(functionName);
      } else {
        await supabase.rpc(functionName, params: parameters);
      }
    } catch (e) {
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }
}
