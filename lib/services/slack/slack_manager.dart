import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/supabase/edge/supabase_edge_function.dart';

class SlackManager {
  static Future<void> sendMessage({required String destination, required String message}) async {
    try {
      await SupabaseEdgeFunction.invokeFunction(
        'slack-message',
        payload: {
          'destination': destination,
          'content': message,
        },
      );
      AppLogger.info('Slack message sent to $destination');
    } catch (e, stack) {
      AppLogger.error('Failed to send Slack message to $destination', e, stack);
      throw Exception('Failed to send Slack message: ${e.toString()}');
    }
  }
}