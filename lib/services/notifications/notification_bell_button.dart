import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'notification_manager.dart';
import 'notification_panel.dart';

/// Notification bell button with unread indicator badge
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key, required this.manager});

  final NotificationManager manager;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  bool _hasUnread = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _updateUnreadStatus();
    widget.manager.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _updateUnreadStatus() {
    _hasUnread = widget.manager.hasUnreadNotifications;
    _unreadCount = widget.manager.unreadCount;
  }

  void _onNotificationsChanged() {
    if (mounted) {
      setState(() {
        _updateUnreadStatus();
      });
    }
  }

  void _openNotificationPanel() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return NotificationPanel(manager: widget.manager);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasUnread = _hasUnread;
    final unreadCount = _unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            hasUnread ? Symbols.notifications_active : Symbols.notifications,
            color: colorScheme.primary,
          ),
          onPressed: _openNotificationPanel,
          tooltip: 'Notifications',
        ),
        if (hasUnread)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: unreadCount > 99 ? 8 : 10,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
