import 'package:boot_app/services/misc/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEdgeFunction {
  static final supabase = Supabase.instance.client;

  static Future<dynamic> invokeFunction(
    String functionName, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        functionName,
        body: payload,
      );
      if (response.status != 200) {
        AppLogger.error(
          'Error invoking edge function $functionName: Status ${response.status}',
        );
        throw Exception('Function invocation failed');
      }
      return response.data;
    } catch (e, stack) {
      AppLogger.error('Unexpected error invoking function $functionName', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }
}