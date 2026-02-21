import 'package:boot_app/services/misc/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDB {
  static final supabase = Supabase.instance.client;

  //Select/Get
  static Future<List<Map<String, dynamic>>> selectData({
    List<String>? columns,
    required String table,
  }) async {
    try {
      if (columns == null || columns.isEmpty) {
        return await supabase.from(table).select();
      }
      return await supabase.from(table).select(columns.join(', '));
    } catch (e, stack) {
      AppLogger.error('Error selecting data from $table', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getDataValue({
    required String table,
    required String column,
    required dynamic value,
  }) async {
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
    try {
      return await supabase.from(table).select().inFilter(column, columnValue);
    } catch (e, stack) {
      AppLogger.error(
        'Error getting multiple row data from $table for $column',
        e,
        stack,
      );
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllRowData({
    required String table,
  }) async {
    try {
      return await supabase.from(table).select();
    } catch (e, stack) {
      AppLogger.error('Error getting all row data from $table', e, stack);
      throw Exception('Unexpected error: ${e.toString()}');
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
