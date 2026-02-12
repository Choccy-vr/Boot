import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// Severity level for notification styling and behavior
enum NotificationSeverity { error, warning, info, success, promotional }

/// Category determines persistence and display behavior
enum NotificationCategory {
  /// Transient errors - shown but not saved, auto-dismiss
  transientError,

  /// Important errors - shown and saved to history
  persistentError,

  /// General warnings - shown and saved
  warning,

  /// Informational messages - shown and saved
  info,

  /// Success confirmations - shown but not saved, auto-dismiss
  success,

  /// Promotional/feature announcements - shown and saved
  promotional,

  /// System updates - shown and saved
  system,
}

/// Notification model with full configuration
class AppNotification {
  AppNotification({
    required this.id,
    required this.message,
    required this.category,
    this.title,
    this.severity,
    this.autoDismissSeconds = 0,
    this.actionLabel,
    this.onActionTap,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now() {
    // Auto-infer severity from category if not provided
    severity ??= _inferSeverity(category);
  }

  final int id;
  final String message;
  final String? title;
  final NotificationCategory category;
  NotificationSeverity? severity;
  final DateTime timestamp;

  /// Auto-dismiss duration in seconds (0 = no auto-dismiss)
  final int autoDismissSeconds;

  /// Optional action button
  final String? actionLabel;
  final VoidCallback? onActionTap;

  /// Whether this notification should be saved to history
  bool get shouldPersist {
    switch (category) {
      case NotificationCategory.transientError:
      case NotificationCategory.success:
        return false;
      case NotificationCategory.persistentError:
      case NotificationCategory.warning:
      case NotificationCategory.info:
      case NotificationCategory.promotional:
      case NotificationCategory.system:
        return true;
    }
  }

  /// Whether this notification should auto-dismiss
  bool get shouldAutoDismiss => autoDismissSeconds > 0;

  static NotificationSeverity _inferSeverity(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.transientError:
      case NotificationCategory.persistentError:
        return NotificationSeverity.error;
      case NotificationCategory.warning:
        return NotificationSeverity.warning;
      case NotificationCategory.info:
      case NotificationCategory.system:
        return NotificationSeverity.info;
      case NotificationCategory.success:
        return NotificationSeverity.success;
      case NotificationCategory.promotional:
        return NotificationSeverity.promotional;
    }
  }
}

/// Visual styling configuration for each severity level
class NotificationPalette {
  const NotificationPalette({
    required this.background,
    required this.border,
    required this.text,
    required this.icon,
    required this.iconColor,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color text;
  final IconData icon;
  final Color iconColor;
  final Color shadow;

  static NotificationPalette fromSeverity(
    NotificationSeverity severity,
    ColorScheme colorScheme,
  ) {
    switch (severity) {
      case NotificationSeverity.error:
        return NotificationPalette(
          background: colorScheme.errorContainer,
          border: colorScheme.error,
          text: colorScheme.onErrorContainer,
          icon: Symbols.error,
          iconColor: colorScheme.error,
          shadow: colorScheme.error.withValues(alpha: 0.25),
        );
      case NotificationSeverity.warning:
        return NotificationPalette(
          background: colorScheme.tertiaryContainer,
          border: colorScheme.tertiary,
          text: colorScheme.onTertiaryContainer,
          icon: Symbols.warning,
          iconColor: colorScheme.tertiary,
          shadow: colorScheme.tertiary.withValues(alpha: 0.25),
        );
      case NotificationSeverity.info:
        return NotificationPalette(
          background: colorScheme.primaryContainer,
          border: colorScheme.primary,
          text: colorScheme.onPrimaryContainer,
          icon: Symbols.info,
          iconColor: colorScheme.primary,
          shadow: colorScheme.primary.withValues(alpha: 0.25),
        );
      case NotificationSeverity.success:
        return NotificationPalette(
          background: colorScheme.secondaryContainer,
          border: colorScheme.secondary,
          text: colorScheme.onSecondaryContainer,
          icon: Symbols.check_circle,
          iconColor: colorScheme.secondary,
          shadow: colorScheme.secondary.withValues(alpha: 0.25),
        );
      case NotificationSeverity.promotional:
        return NotificationPalette(
          background: colorScheme.primaryContainer.withValues(alpha: 0.6),
          border: colorScheme.primary,
          text: colorScheme.onPrimaryContainer,
          icon: Symbols.campaign,
          iconColor: colorScheme.primary,
          shadow: colorScheme.primary.withValues(alpha: 0.3),
        );
    }
  }
}
