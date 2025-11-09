import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Logger utility for the Boot app
class AppLogger {
  static final Logger _logger = Logger('BootApp');

  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  static Logger get logger => _logger;

  static void debug(String message) => _logger.fine(message);
  static void info(String message) => _logger.info(message);
  static void warning(String message) => _logger.warning(message);
  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
