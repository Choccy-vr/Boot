import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../notifications/global_notification_service.dart';

class AppLogger {
  static final Logger _logger = Logger('BootApp');

  /// Toggle to surface warnings/errors as in-app notifications
  static bool enableNotifications = true;

  static void init() {
    // Set log level based on environment
    final isLocalhost = _isRunningOnLocalhost();
    Logger.root.level = isLocalhost ? Level.FINEST : Level.SEVERE;
    
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  static bool _isRunningOnLocalhost() {
    if (!kIsWeb) return kDebugMode;
    
    // For web, check the hostname
    try {
      final hostname = Uri.base.host;
      return hostname == 'localhost' || 
             hostname == '127.0.0.1' || 
             hostname.startsWith('localhost:') ||
             hostname.startsWith('127.0.0.1:');
    } catch (e) {
      return false;
    }
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
