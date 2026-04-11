import 'package:boot_app/services/prizes/Prize.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';
import 'package:boot_app/services/misc/logger.dart';

class PrizeService {
  static List<Prize> prizes = [];

  static Future<List<Prize>> fetchPrizes() async {
    try {
      final response = await SupabaseDB.getAllRowData(table: 'prizes');
      prizes = (response as List).map((json) => Prize.fromJson(json)).toList();
      return prizes;
    } catch (e, stack) {
      AppLogger.error('Error getting prizes', e, stack);
      return [];
    }
  }

  static Future<void> updatePrizes() async {
    try {
      final response = await SupabaseDB.getAllRowData(table: 'prizes');
      prizes = (response as List).map((json) => Prize.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.error('Error getting prizes', e, stack);
    }
  }

  static Future<Prize?> getPrizeById(String id) async {
    try {
      final response = await SupabaseDB.getRowData(table: 'prizes', rowID: id);
      return Prize.fromJson(response);
    } catch (e, stack) {
      AppLogger.error('Error getting prize with id $id', e, stack);
      return null;
    }
  }

  static Future<List<Prize>> getPrizesByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];
      final response = await SupabaseDB.getMultipleRowData(
        table: 'prizes',
        column: 'id',
        columnValue: ids,
      );
      return (response as List).map((json) => Prize.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.error('Error getting prizes by ids', e, stack);
      return [];
    }
  }

  static Future<List<Prize>> getPrizesByKeys(List<String> keys) async {
    try {
      if (keys.isEmpty) return [];
      final response = await SupabaseDB.getMultipleRowData(
        table: 'prizes',
        column: 'key',
        columnValue: keys,
      );
      return (response as List).map((json) => Prize.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.error('Error getting prizes by keys', e, stack);
      return [];
    }
  }

  static Future<List<PrizeOption>> getPrizeOptions(Prize prize) async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'prize_options',
        column: 'prize_id',
        columnValue: [prize.id],
      );
      return (response as List)
          .map((json) => PrizeOption.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Error getting options for prize ${prize.id}', e, stack);
      return [];
    }
  }

  static Future<List<PrizeOptionValues>> getPrizeOptionValues(
    PrizeOption option,
  ) async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'prize_option_values',
        column: 'option_id',
        columnValue: [option.id],
      );
      return (response as List)
          .map((json) => PrizeOptionValues.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Error getting values for option ${option.id}', e, stack);
      return [];
    }
  }

  static Future<void> updatePrizeWithOptions(Prize prize) async {
    try {
      final options = await getPrizeOptions(prize);
      final optionValues = (await Future.wait(
        options.map(getPrizeOptionValues),
      )).expand((values) => values).toList();

      prize.options = options;
      for (var option in prize.options) {
        option.values = optionValues
            .where((value) => value.optionId == option.id)
            .toList();
      }
    } catch (e, stack) {
      AppLogger.error('Error getting options for prize ${prize.id}', e, stack);
    }
  }

  static Future<List<Prize>> purchasePrizes(List<Prize> selectedPrizes) async {
    try {
      return selectedPrizes;
    } catch (e, stack) {
      AppLogger.error('Error purchasing prizes. Try again later.', e, stack);
      return [];
    }
  }

  static Future<bool> purchaseGrant(Prize prize, int amount) async {
    try {
      AppLogger.info('Purchasing: ${prize.title}');
      return true;
    } catch (e, stack) {
      AppLogger.error('Error purchasing grant ${prize.id}', e, stack);
      return false;
    }
  }
}
