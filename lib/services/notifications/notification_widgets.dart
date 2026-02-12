import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'notification_model.dart';
import 'notification_manager.dart';

/// Animated notification widget with live timestamp updates
class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onDismiss,
    required this.colorScheme,
    required this.textTheme,
  });

  final AppNotification notification;
  final VoidCallback onDismiss;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timestampUpdateTimer;
  String _formattedTimestamp = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    _updateTimestamp();

    // Update timestamp every second
    _timestampUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTimestamp(),
    );
  }

  void _updateTimestamp() {
    final newTimestamp = _formatTimestamp(widget.notification.timestamp);
    if (newTimestamp != _formattedTimestamp) {
      if (mounted) {
        setState(() {
          _formattedTimestamp = newTimestamp;
        });
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 5) return 'just now';
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  Future<void> _handleDismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timestampUpdateTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = NotificationPalette.fromSeverity(
      widget.notification.severity!,
      widget.colorScheme,
    );

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: 340,
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  leading: Icon(
                    palette.icon,
                    color: palette.iconColor,
                    size: 24,
                  ),
                  title: widget.notification.title != null
                      ? Text(
                          widget.notification.title!,
                          style: widget.textTheme.titleSmall?.copyWith(
                            color: palette.text,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.notification.title != null)
                        const SizedBox(height: 4),
                      Text(
                        widget.notification.message,
                        style: widget.textTheme.bodyMedium?.copyWith(
                          color: palette.text,
                          fontWeight: widget.notification.title != null
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formattedTimestamp,
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: palette.text.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: Semantics(
                    label: 'Dismiss notification',
                    button: true,
                    child: IconButton(
                      onPressed: _handleDismiss,
                      icon: Icon(
                        Symbols.close,
                        color: palette.iconColor,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ),
                if (widget.notification.actionLabel != null &&
                    widget.notification.onActionTap != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          widget.notification.onActionTap?.call();
                          _handleDismiss();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.iconColor,
                          side: BorderSide(color: palette.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(widget.notification.actionLabel!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Notification center overlay widget
class NotificationCenter extends StatefulWidget {
  const NotificationCenter({
    super.key,
    required this.manager,
    required this.colorScheme,
    required this.textTheme,
  });

  final NotificationManager manager;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = widget.manager.activeNotifications;
    if (notifications.isEmpty) return const SizedBox.shrink();

    final visibleNotifications = _isHovering || notifications.length == 1
        ? notifications
        : [notifications.last];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isHovering && notifications.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${notifications.length} notifications',
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: widget.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.manager.dismissAll,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Symbols.clear_all,
                            size: 16,
                            color: widget.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ...visibleNotifications.map(
            (notification) => NotificationCard(
              key: ValueKey(notification.id),
              notification: notification,
              onDismiss: () => widget.manager.dismiss(notification.id),
              colorScheme: widget.colorScheme,
              textTheme: widget.textTheme,
            ),
          ),
        ],
      ),
    );
  }
}
