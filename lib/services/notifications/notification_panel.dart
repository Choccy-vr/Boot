import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'notification_model.dart';
import 'notification_manager.dart';

/// Full-screen notification panel showing all notification history
class NotificationPanel extends StatefulWidget {
  const NotificationPanel({super.key, required this.manager});

  final NotificationManager manager;

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

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

    _animationController.forward();

    // Mark all notifications as read when panel is opened
    widget.manager.markAllAsRead();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final notifications = widget.manager.notificationHistory;

    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        onTap: _close,
        child: Container(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping panel content
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: 420,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(-4, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest,
                          border: Border(
                            bottom: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Symbols.notifications,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Notifications',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (notifications.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  widget.manager.clearHistory();
                                  setState(() {});
                                },
                                icon: Icon(
                                  Symbols.delete_sweep,
                                  size: 18,
                                  color: colorScheme.error,
                                ),
                                label: Text(
                                  'Clear All',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _close,
                              icon: Icon(
                                Symbols.close,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Notification list
                      Expanded(
                        child: notifications.isEmpty
                            ? _buildEmptyState(colorScheme, textTheme)
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: notifications.length,
                                itemBuilder: (context, index) {
                                  final notification = notifications[index];
                                  return _NotificationHistoryItem(
                                    notification: notification,
                                    colorScheme: colorScheme,
                                    textTheme: textTheme,
                                    onDismiss: () {
                                      widget.manager.removeFromHistory(
                                        notification.id,
                                      );
                                      setState(() {});
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.notifications_off,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual notification item in the history panel
class _NotificationHistoryItem extends StatelessWidget {
  const _NotificationHistoryItem({
    required this.notification,
    required this.colorScheme,
    required this.textTheme,
    required this.onDismiss,
  });

  final AppNotification notification;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onDismiss;

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()}w ago';
    return '${(difference.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final palette = NotificationPalette.fromSeverity(
      notification.severity!,
      colorScheme,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: notification.onActionTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(palette.icon, color: palette.iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notification.title != null) ...[
                        Text(
                          notification.title!,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        notification.message,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Remove notification',
                  button: true,
                  child: IconButton(
                    onPressed: onDismiss,
                    icon: Icon(
                      Symbols.close,
                      color: colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
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
