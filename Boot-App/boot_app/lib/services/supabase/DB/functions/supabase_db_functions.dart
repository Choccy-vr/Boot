import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDBFunctions {
  static final supabase = Supabase.instance.client;

  static Future<void> callDbFunction({
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

  static Future<void> callIncrementFunction({
    required String table,
    required String column,
    required String rowID,
    required int incrementBy,
  }) async {
    try {
      await supabase.rpc(
        'increment_field_value',
        params: {
          'table_name': table,
          'field_name': column,
          'row_id': rowID,
          'increment_amount': incrementBy,
        },
      );
    } catch (e) {
      throw Exception('Failed to increment column: ${e.toString()}');
    }
  }
}
