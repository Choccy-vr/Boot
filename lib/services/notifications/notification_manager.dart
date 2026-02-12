import 'dart:async';
import 'package:flutter/material.dart';
import 'notification_model.dart';

/// Manages notification state, auto-dismiss timers, and history
class NotificationManager extends ChangeNotifier {
  final List<AppNotification> _activeNotifications = [];
  final List<AppNotification> _notificationHistory = [];
  final Map<int, Timer> _autoDismissTimers = {};
  final Set<int> _readNotifications = {};
  int _notificationIdSeed = 0;

  List<AppNotification> get activeNotifications =>
      List.unmodifiable(_activeNotifications);
  List<AppNotification> get notificationHistory =>
      List.unmodifiable(_notificationHistory);

  /// Check if there are any unread notifications
  bool get hasUnreadNotifications {
    try {
      return _notificationHistory.any(
        (n) => !_readNotifications.contains(n.id),
      );
    } catch (e) {
      return false;
    }
  }

  /// Get count of unread notifications
  int get unreadCount {
    try {
      return _notificationHistory
          .where((n) => !_readNotifications.contains(n.id))
          .length;
    } catch (e) {
      return 0;
    }
  }

  /// Show a new notification
  void show({
    required String message,
    String? title,
    NotificationCategory category = NotificationCategory.info,
    NotificationSeverity? severity,
    int autoDismissSeconds = 0,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    final notification = AppNotification(
      id: ++_notificationIdSeed,
      message: message,
      title: title,
      category: category,
      severity: severity,
      autoDismissSeconds: autoDismissSeconds,
      actionLabel: actionLabel,
      onActionTap: onActionTap,
    );

    _activeNotifications.add(notification);

    // Save to history if persistent
    if (notification.shouldPersist) {
      _notificationHistory.insert(0, notification);
      // Limit history to 50 items
      if (_notificationHistory.length > 50) {
        _notificationHistory.removeLast();
      }
    }

    // Set up auto-dismiss timer
    if (notification.shouldAutoDismiss) {
      _autoDismissTimers[notification.id] = Timer(
        Duration(seconds: notification.autoDismissSeconds),
        () => dismiss(notification.id),
      );
    }

    notifyListeners();
  }

  /// Dismiss a notification by ID
  void dismiss(int id) {
    _activeNotifications.removeWhere((n) => n.id == id);
    _autoDismissTimers[id]?.cancel();
    _autoDismissTimers.remove(id);
    notifyListeners();
  }

  /// Dismiss all active notifications
  void dismissAll() {
    _activeNotifications.clear();
    for (final timer in _autoDismissTimers.values) {
      timer.cancel();
    }
    _autoDismissTimers.clear();
    notifyListeners();
  }

  /// Clear notification history
  void clearHistory() {
    _notificationHistory.clear();
    _readNotifications.clear();
    notifyListeners();
  }

  /// Remove a specific notification from history
  void removeFromHistory(int id) {
    _notificationHistory.removeWhere((n) => n.id == id);
    _readNotifications.remove(id);
    notifyListeners();
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (final notification in _notificationHistory) {
      _readNotifications.add(notification.id);
    }
    notifyListeners();
  }

  /// Mark a specific notification as read
  void markAsRead(int id) {
    _readNotifications.add(id);
    notifyListeners();
  }

  /// Check if a notification is read
  bool isRead(int id) {
    return _readNotifications.contains(id);
  }

  @override
  void dispose() {
    for (final timer in _autoDismissTimers.values) {
      timer.cancel();
    }
    _autoDismissTimers.clear();
    super.dispose();
  }

  // Convenience methods for common notification types

  void showError(String message, {String? title, bool persistent = false}) {
    show(
      message: message,
      title: title,
      category: persistent
          ? NotificationCategory.persistentError
          : NotificationCategory.transientError,
      autoDismissSeconds: persistent ? 0 : 10,
    );
  }

  void showWarning(String message, {String? title}) {
    show(
      message: message,
      title: title,
      category: NotificationCategory.warning,
      autoDismissSeconds: 15,
    );
  }

  void showInfo(String message, {String? title}) {
    show(
      message: message,
      title: title,
      category: NotificationCategory.info,
      autoDismissSeconds: 8,
    );
  }

  void showSuccess(String message, {String? title}) {
    show(
      message: message,
      title: title,
      category: NotificationCategory.success,
      autoDismissSeconds: 5,
    );
  }

  void showPromo(
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    show(
      message: message,
      title: title,
      category: NotificationCategory.promotional,
      autoDismissSeconds: 0, // Promos don't auto-dismiss
      actionLabel: actionLabel,
      onActionTap: onActionTap,
    );
  }
}
