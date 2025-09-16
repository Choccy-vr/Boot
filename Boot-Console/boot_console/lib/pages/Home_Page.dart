import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  final String _welcomeText = "Boot Admin Console";

  // Mock data for demonstration
  final Map<String, dynamic> _systemStats = {
    'totalUsers': 1247,
    'activeProjects': 89,
    'totalDevlogs': 432,
    'storageUsed': '2.3 GB',
    'serverUptime': '14d 7h 23m',
    'onlineUsers': 34,
  };

  @override
  void initState() {
    super.initState();
    _typewriterController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _typewriterAnimation = IntTween(begin: 0, end: _welcomeText.length).animate(
      CurvedAnimation(parent: _typewriterController, curve: Curves.easeInOut),
    );
    _typewriterController.forward();
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status.toLowerCase()) {
      case 'operational':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'maintenance':
        return Colors.blue;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildTerminalHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'admin@boot-console:~/',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              String visibleText = _welcomeText.substring(
                0,
                _typewriterAnimation.value.clamp(0, _welcomeText.length),
              );
              return Row(
                children: [
                  Text(
                    '\$ echo "',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.secondary,
                    ),
                  ),
                  Text(
                    visibleText,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_typewriterAnimation.value >= _welcomeText.length)
                    Text(
                      '"',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                  if (_typewriterAnimation.value < _welcomeText.length)
                    Container(width: 2, height: 20, color: colorScheme.primary),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'System Status: ${DateTime.now().toString().split('.')[0]}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme, TextTheme textTheme) {
    final actions = [
      {
        'title': 'User Management',
        'subtitle': 'Manage users and permissions',
        'icon': Symbols.manage_accounts,
        'color': colorScheme.primary,
      },
      {
        'title': 'Project Monitoring',
        'subtitle': 'View and moderate projects',
        'icon': Symbols.monitoring,
        'color': colorScheme.secondary,
      },
      {
        'title': 'System Logs',
        'subtitle': 'View application logs',
        'icon': Symbols.terminal,
        'color': colorScheme.tertiary,
      },
      {
        'title': 'Database Admin',
        'subtitle': 'Manage database operations',
        'icon': Symbols.database,
        'color': colorScheme.primary,
      },
      {
        'title': 'File Storage',
        'subtitle': 'Manage uploaded files',
        'icon': Symbols.folder_open,
        'color': colorScheme.secondary,
      },
      {
        'title': 'Analytics',
        'subtitle': 'View usage statistics',
        'icon': Symbols.analytics,
        'color': colorScheme.tertiary,
      },
    ];

    return Card(
      color: colorScheme.surfaceContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.dashboard, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return InkWell(
                  onTap: () {
                    // Add navigation logic here
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          action['icon'] as IconData,
                          color: action['color'] as Color,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                action['title'] as String,
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                action['subtitle'] as String,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Symbols.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(ColorScheme colorScheme, TextTheme textTheme) {
    final activities = [
      {
        'type': 'user_signup',
        'message': 'New user registration: john_doe',
        'time': '2 minutes ago',
        'icon': Symbols.person_add,
        'color': Colors.green,
      },
      {
        'type': 'project_created',
        'message': 'Project "AI Assistant" created by alice_smith',
        'time': '15 minutes ago',
        'icon': Symbols.folder_data,
        'color': colorScheme.secondary,
      },
      {
        'type': 'devlog_posted',
        'message': 'New devlog posted in "Web Framework"',
        'time': '1 hour ago',
        'icon': Symbols.article,
        'color': colorScheme.tertiary,
      },
      {
        'type': 'file_uploaded',
        'message': 'Large file uploaded: project_demo.mp4 (125MB)',
        'time': '2 hours ago',
        'icon': Symbols.upload,
        'color': colorScheme.primary,
      },
      {
        'type': 'error',
        'message': 'Database connection timeout (resolved)',
        'time': '3 hours ago',
        'icon': Symbols.error,
        'color': Colors.orange,
      },
    ];

    return Card(
      color: colorScheme.surfaceContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.history, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: () {
                    // Add navigation to full activity log
                  },
                  child: Text(
                    'View All',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = activities[index];

                return Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        activity['icon'] as IconData,
                        color: activity['color'] as Color,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          activity['message'] as String,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        activity['time'] as String,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Boot Admin Console',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Symbols.notifications, color: colorScheme.onSurface),
            onPressed: () {
              // Add notifications logic
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: Icon(Symbols.settings, color: colorScheme.onSurface),
            onPressed: () {
              // Add settings logic
            },
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTerminalHeader(colorScheme, textTheme),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [_buildQuickActions(colorScheme, textTheme)],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: _buildRecentActivity(colorScheme, textTheme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
