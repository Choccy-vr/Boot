import 'package:boot_app/services/misc/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/main.dart' show supabaseUrl, supabaseKey;

class SupabaseDB {
  static final supabase = Supabase.instance.client;

  static bool get _isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  //Select/Get
  static Future<List<Map<String, dynamic>>> selectData({
    List<String>? columns,
    required String table,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. selectData returning empty list.');
      return [];
    }
    try {
      final dynamic result;
      if (columns == null || columns.isEmpty) {
        result = await supabase.from(table).select();
      } else {
        result = await supabase.from(table).select(columns.join(', '));
      }
      if (result == null) return [];
      return List<Map<String, dynamic>>.from(result);
    } catch (e, stack) {
      AppLogger.error('Error selecting data from $table', e, stack);
      return [];
    }
  }

  static Future<Map<String, dynamic>> getDataValue({
    required String table,
    required String column,
    required dynamic value,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. getDataValue returning empty map.');
      return {};
    }
    try {
      return await supabase.from(table).select().eq(column, value).single();
    } catch (e, stack) {
      AppLogger.error(
        'Error getting data value from $table where $column = $value',
        e,
        stack,
      );
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getRowData({
    required String table,
    required dynamic rowID,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. getRowData returning empty map.');
      return {};
    }
    try {
      return await supabase.from(table).select().eq('id', rowID).single();
    } catch (e, stack) {
      AppLogger.error(
        'Error getting row data from $table for id $rowID',
        e,
        stack,
      );
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getMultipleRowData({
    required String table,
    required String column,
    required List<dynamic> columnValue,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. getMultipleRowData returning empty list.');
      return [];
    }
    try {
      final dynamic result = await supabase.from(table).select().inFilter(column, columnValue);
      if (result == null) return [];
      return List<Map<String, dynamic>>.from(result);
    } catch (e, stack) {
      AppLogger.error(
        'Error getting multiple row data from $table for $column',
        e,
        stack,
      );
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllRowData({
    required String table,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. getAllRowData returning empty list.');
      return [];
    }
    try {
      final dynamic result = await supabase.from(table).select();
      if (result == null) return [];
      return List<Map<String, dynamic>>.from(result);
    } catch (e, stack) {
      AppLogger.error('Error getting all row data from $table', e, stack);
      return [];
    }
  }

  //Insert
  static Future<void> insertData({
    required String table,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? bulkData,
  }) async {
    // Ensure exactly one parameter is provided
    if ((data == null && bulkData == null) ||
        (data != null && bulkData != null)) {
      throw ArgumentError(
        'Provide either data or bulkData, but not both or neither',
      );
    }

    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. Skipping insertData.');
      return;
    }

    try {
      if (data != null) {
        await supabase.from(table).insert(data);
      } else {
        await supabase.from(table).insert(bulkData!);
      }
    } catch (e, stack) {
      AppLogger.error('Error inserting data into $table', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> insertAndReturnData({
    required String table,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? bulkData,
  }) async {
    // Ensure exactly one parameter is provided
    if ((data == null && bulkData == null) ||
        (data != null && bulkData != null)) {
      throw ArgumentError(
        'Provide either data or bulkData, but not both or neither',
      );
    }

    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. insertAndReturnData returning empty list.');
      return [];
    }

    try {
      if (data != null) {
        return await supabase.from(table).insert(data).select();
      } else {
        return await supabase.from(table).insert(bulkData!).select();
      }
    } catch (e, stack) {
      AppLogger.error('Error inserting data into $table with return', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  //Update
  static Future<void> updateData({
    required String table,
    required Map<String, dynamic> data,
    required String column,
    required dynamic value,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. Skipping updateData.');
      return;
    }
    try {
      await supabase.from(table).update(data).eq(column, value);
    } catch (e, stack) {
      AppLogger.error('Error updating $table where $column = $value', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> updateAndReturnData({
    required String table,
    required Map<String, dynamic> data,
    required String column,
    required dynamic value,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. updateAndReturnData returning empty list.');
      return [];
    }
    try {
      final response = await supabase
          .from(table)
          .update(data)
          .eq(column, value)
          .select();
      return response;
    } catch (e, stack) {
      AppLogger.error(
        'Error updating data and returning from $table',
        e,
        stack,
      );
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<void> updateBulkData({
    required String table,
    required List<Map<String, dynamic>> bulkData,
    String onConflict = 'id',
    bool? defaultToNull,
  }) async {
    if (bulkData.isEmpty) return;

    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. Skipping updateBulkData.');
      return;
    }

    try {
      final upsertArgs = <String, dynamic>{
        'onConflict': onConflict,
        'ignoreDuplicates': false,
      };
      if (defaultToNull != null) upsertArgs['defaultToNull'] = defaultToNull;

      await Function.apply(
        supabase.from(table).upsert,
        [bulkData],
        upsertArgs.map((k, v) => MapEntry(Symbol(k), v)),
      );
    } catch (e, stack) {
      AppLogger.error('Error bulk updating data in $table', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  //Upsert
  static Future<List<Map<String, dynamic>>> upsertData({
    required String table,
    String? onConflict,
    bool? defaultToNull,
    bool? ignoreDuplicates,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? bulkData,
  }) async {
    // Ensure exactly one parameter is provided
    if ((data == null && bulkData == null) ||
        (data != null && bulkData != null)) {
      throw ArgumentError(
        'Provide either data or bulkData, but not both or neither',
      );
    }

    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. upsertData returning empty list.');
      return [];
    }

    try {
      final upsertArgs = <String, dynamic>{};
      if (onConflict != null) upsertArgs['onConflict'] = onConflict;
      if (defaultToNull != null) upsertArgs['defaultToNull'] = defaultToNull;
      if (ignoreDuplicates != null) {
        upsertArgs['ignoreDuplicates'] = ignoreDuplicates;
      }

      if (data != null) {
        return await Function.apply(
          supabase.from(table).upsert,
          [data],
          upsertArgs.map((k, v) => MapEntry(Symbol(k), v)),
        ).select();
      } else {
        return await Function.apply(
          supabase.from(table).upsert,
          [bulkData!],
          upsertArgs.map((k, v) => MapEntry(Symbol(k), v)),
        ).select();
      }
    } catch (e, stack) {
      AppLogger.error('Error upserting data into $table', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  //Delete
  static Future<void> deleteData({
    required String table,
    required String column,
    dynamic value,
    List<dynamic>? values,
  }) async {
    // Ensure exactly one parameter is provided
    if ((value == null && values == null) ||
        (value != null && values != null)) {
      throw ArgumentError(
        'Provide either value or values, but not both or neither',
      );
    }

    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. Skipping deleteData.');
      return;
    }

    try {
      if (value != null) {
        await supabase.from(table).delete().eq(column, value);
      } else {
        await supabase.from(table).delete().inFilter(column, values!);
      }
    } catch (e, stack) {
      AppLogger.error(
        'Error deleting data from $table where $column',
        e,
        stack,
      );
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  //RPC/Function calls
  static Future<dynamic> callDbFunction({
    required String functionName,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isConfigured) {
      AppLogger.info('Supabase is not configured. callDbFunction returning null.');
      return null;
    }
    try {
      if (parameters != null) {
        return await supabase.rpc(functionName, params: parameters);
      } else {
        return await supabase.rpc(functionName);
      }
    } catch (e, stack) {
      AppLogger.error('Function call $functionName failed', e, stack);
      throw Exception('Function call failed: ${e.toString()}');
    }
  }
}
