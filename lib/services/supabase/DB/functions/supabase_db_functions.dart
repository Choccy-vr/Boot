import 'package:boot_app/services/misc/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/main.dart' show supabaseUrl, supabaseKey;

class SupabaseDBFunctions {
  static final supabase = Supabase.instance.client;

  static bool get _isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  static Future<void> callDbFunction({
    required String functionName,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. callDbFunction skipped.');
      return;
    }
    try {
      if (parameters == null) {
        await supabase.rpc(functionName);
      } else {
        await supabase.rpc(functionName, params: parameters);
      }
    } catch (e, stack) {
      AppLogger.error('Function $functionName failed', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<void> callIncrementFunction({
    required String table,
    required String column,
    required String rowID,
    required int incrementBy,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. callIncrementFunction skipped.');
      return;
    }
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
    } catch (e, stack) {
      AppLogger.error(
        'Failed to increment $table.$column for row $rowID by $incrementBy',
        e,
        stack,
      );
      throw Exception('Failed to increment column: ${e.toString()}');
    }
  }
}
