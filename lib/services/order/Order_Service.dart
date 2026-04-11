import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/prizes/Prize.dart';
import 'package:boot_app/services/supabase/edge/supabase_edge_function.dart';

class OrderService {
  static Future<bool> placeOrder(
    Prize prize,
    int quantity,
    List<PrizeOptionValues>? selectedOptionValues,
  ) async {
    try {
      final payload = {
        'prize': {'id': prize.id},
        'quantity': quantity,
        if (selectedOptionValues != null && selectedOptionValues.isNotEmpty)
          'selectedOptionValues': selectedOptionValues
              .map((v) => {'id': v.id})
              .toList(),
      };
      await SupabaseEdgeFunction.invokeFunction('shop-order', payload: payload);
      return true;
    } catch (e) {
      AppLogger.error('Error placing order', e);
      return false;
    }
  }
}
