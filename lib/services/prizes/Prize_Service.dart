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
