import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../notifications/global_notification_service.dart';

class AppLogger {
  static final Logger _logger = Logger('BootApp');

  /// Toggle to surface warnings/errors as in-app notifications
  static bool enableNotifications = true;

  static void init() {
    Logger.root.level = Level.FINEST; // Set default log level to SEVERE
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  static Logger get logger => _logger;

  static void debug(String message) => _logger.fine(message);
  static void info(String message) => _logger.info(message);
  static void warning(String message) {
    _logger.warning(message);
    _notifyWarning(message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
    _notifyError(_composeErrorMessage(message, error));
  }

  static void _notifyWarning(String message) {
    if (!enableNotifications) return;
    GlobalNotificationService.instance.showWarning(message);
  }

  static void _notifyError(String message) {
    if (!enableNotifications) return;
    GlobalNotificationService.instance.showError(message, persistent: true);
  }

  static String _composeErrorMessage(String message, Object? error) {
    if (error == null) return message;
    return '$message ($error)';
  }
}
