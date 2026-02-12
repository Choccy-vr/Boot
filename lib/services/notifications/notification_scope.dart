import 'package:flutter/material.dart';

import 'notification_manager.dart';
import 'notification_widgets.dart';
import 'global_notification_service.dart';

/// Wraps a widget tree with a shared [NotificationManager] and overlay.
class NotificationScope extends StatefulWidget {
  const NotificationScope({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationScope> createState() => _NotificationScopeState();

  /// Get the NotificationManager from the nearest NotificationScope ancestor
  static NotificationManager? of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_InheritedNotificationScope>();
    return inherited?.manager;
  }
}

class _NotificationScopeState extends State<NotificationScope> {
  late final NotificationManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = NotificationManager();
    GlobalNotificationService.instance.registerManager(_manager);
  }

  @override
  void dispose() {
    GlobalNotificationService.instance.unregisterManager();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _InheritedNotificationScope(
      manager: _manager,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 24,
            right: 24,
            child: NotificationCenter(
              manager: _manager,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}

/// InheritedWidget to provide NotificationManager down the widget tree
class _InheritedNotificationScope extends InheritedWidget {
  const _InheritedNotificationScope({
    required this.manager,
    required super.child,
  });

  final NotificationManager manager;

  @override
  bool updateShouldNotify(_InheritedNotificationScope oldWidget) {
    return manager != oldWidget.manager;
  }
}
