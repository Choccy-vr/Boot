import 'package:flutter/material.dart';
import 'notification_manager.dart';

/// Global notification service for showing notifications from anywhere in the app
///
/// Usage:
/// ```dart
/// GlobalNotificationService.instance.showError('Something went wrong');
/// GlobalNotificationService.instance.showSuccess('Saved successfully!');
/// ```
class GlobalNotificationService {
  static final GlobalNotificationService _instance =
      GlobalNotificationService._internal();
  static GlobalNotificationService get instance => _instance;

  GlobalNotificationService._internal();

  NotificationManager? _manager;

  /// Register the notification manager (typically from a page with NotificationCenter)
  void registerManager(NotificationManager manager) {
    _manager = manager;
  }

  /// Unregister the notification manager (typically in dispose)
  void unregisterManager() {
    _manager = null;
  }

  /// Show an error notification
  void showError(String message, {bool persistent = false}) {
    _manager?.showError(message, persistent: persistent);
  }

  /// Show a warning notification
  void showWarning(String message) {
    _manager?.showWarning(message);
  }

  /// Show an info notification
  void showInfo(String message) {
    _manager?.showInfo(message);
  }

  /// Show a success notification
  void showSuccess(String message) {
    _manager?.showSuccess(message);
  }

  /// Show a promotional notification
  void showPromo(
    String message, {
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    _manager?.showPromo(
      message,
      actionLabel: actionLabel,
      onActionTap: onActionTap,
    );
  }

  /// Check if a manager is registered
  bool get isRegistered => _manager != null;
}
