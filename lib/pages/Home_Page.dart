import 'package:boot_app/services/supabase/auth/Auth.dart';
import 'package:flutter/material.dart';
import '/theme/responsive.dart';
import '/theme/terminal_theme.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../services/navigation/navigation_service.dart';
import '/services/users/User.dart';
import '/services/users/Boot_User.dart';
import '/services/hackatime/hackatime_service.dart';
import '/services/Projects/Project.dart';
import '/services/Projects/project_service.dart';
import '/services/notifications/notifications.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  final String _welcomeText = "Welcome to Boot";
  bool _isHackatimeBanned = false;
  List<Project> _userProjects = [];
  bool _isLoadingProjects = true;

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
    _scheduleHackatimeBanCheck();
    _loadUserProjects();
  }

  Future<void> _loadUserProjects() async {
    final userId = UserService.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoadingProjects = false);
      return;
    }

    try {
      final projects = await ProjectService.getProjects(userId);
      if (mounted) {
        setState(() {
          _userProjects = projects;
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Future<void> _checkHackatimeBanStatus() async {
    if (UserService.currentUser?.hackatimeID != null &&
        UserService.currentUser?.hackatimeApiKey != null) {
      final isBanned = await HackatimeService.isHackatimeBanned(
        userId: UserService.currentUser!.hackatimeID,
        apiKey: UserService.currentUser!.hackatimeApiKey,
        context: context,
      );
      if (mounted) {
        setState(() {
          _isHackatimeBanned = isBanned;
        });
      }
    }
  }

  void _scheduleHackatimeBanCheck() {
    // Try up to 10 times (~2s total) for user credentials to load.
    _attemptHackatimeBanCheck(5);
  }

  void _attemptHackatimeBanCheck(int attempt) async {
    if (!mounted) return;
    final user = UserService.currentUser;
    if (user?.hackatimeID != null && user?.hackatimeApiKey != null) {
      await _checkHackatimeBanStatus();
      return;
    }
    if (attempt >= 10) {
      // Gave up waiting
      return;
    }
    await Future.delayed(const Duration(milliseconds: 200));
    _attemptHackatimeBanCheck(attempt + 1);
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Symbols.menu, color: colorScheme.primary),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: Row(
          children: [
            Icon(Symbols.terminal, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Boot',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final manager = NotificationScope.of(context);
              if (manager == null) {
                return IconButton(
                  icon: Icon(Symbols.notifications, color: colorScheme.primary),
                  onPressed: () {},
                  tooltip: 'Notifications',
                );
              }
              return NotificationBellButton(manager: manager);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(colorScheme, textTheme),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: Responsive.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTerminalHeader(colorScheme, textTheme),
                SizedBox(height: Responsive.spacing(context)),
                if (_isHackatimeBanned) ...[
                  _buildHackatimeBanWarning(colorScheme, textTheme),
                  SizedBox(height: Responsive.spacing(context)),
                ],
                Row(
                  children: [
                    Expanded(child: _buildSystemStatus(colorScheme, textTheme)),
                  ],
                ),
                SizedBox(height: Responsive.spacing(context) * 1.5),
                if (!_isHackatimeBanned) ...[
                  _buildNotificationTestButtons(colorScheme, textTheme),
                  SizedBox(height: Responsive.spacing(context) * 1.5),
                  _buildNavigationGrid(colorScheme, textTheme),
                  SizedBox(height: Responsive.spacing(context) * 1.5),
                  _buildBottomSection(colorScheme, textTheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(ColorScheme colorScheme, TextTheme textTheme) {
    final user = UserService.currentUser;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Symbols.terminal,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Boot',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Symbols.close, color: colorScheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close menu',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (user != null)
                    Text(
                      '${user.username}@ysws',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Symbols.home,
                  title: 'Dashboard',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.pop(context);
                    NavigationService.navigateTo(
                      context: context,
                      destination: AppDestination.home,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Symbols.construction,
                  title: 'My Projects',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.pop(context);
                    NavigationService.navigateTo(
                      context: context,
                      destination: AppDestination.project,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Symbols.explore,
                  title: 'Explore',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.pop(context);
                    NavigationService.navigateTo(
                      context: context,
                      destination: AppDestination.explore,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Symbols.leaderboard,
                  title: 'Leaderboard',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.pop(context);
                    NavigationService.navigateTo(
                      context: context,
                      destination: AppDestination.leaderboard,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Symbols.mountain_flag,
                  title: 'Challenges',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.pop(context);
                    NavigationService.navigateTo(
                      context: context,
                      //TODO: MAKE CHALLENGES DESTINATION
                      destination: AppDestination.leaderboard,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  },
                ),
                // Debug menu item - only for specific user
                if (user?.id == '7f18c57b-ca6f-4812-aac7-a2fb6cc10362')
                  _buildDrawerItem(
                    icon: Symbols.bug_report,
                    title: 'Debug Console',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/debug');
                    },
                  ),
              ],
            ),
          ),
          _buildProfileSection(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildProfileSection(ColorScheme colorScheme, TextTheme textTheme) {
    final user = UserService.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _ProfileCardWithHover(
            user: user,
            colorScheme: colorScheme,
            textTheme: textTheme,
            onTap: () {
              Navigator.pop(context);
              NavigationService.navigateTo(
                context: context,
                destination: AppDestination.profile,
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Authentication.signOut();
                NavigationService.navigateTo(
                  context: context,
                  destination: AppDestination.login,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                );
              },
              icon: Icon(Symbols.logout, size: 18, color: TerminalColors.red),
              label: Text(
                'Logout',
                style: textTheme.bodyMedium?.copyWith(
                  color: TerminalColors.red,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: TerminalColors.red.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? TerminalColors.red : colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: textTheme.bodyLarge?.copyWith(color: color)),
      onTap: onTap,
      hoverColor: colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildHackatimeBanWarning(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TerminalColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TerminalColors.red, width: 2),
      ),
      child: Row(
        children: [
          Icon(Symbols.warning, color: TerminalColors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Warning',
                  style: textTheme.titleLarge?.copyWith(
                    color: TerminalColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Your Hackatime account has been '),
                      TextSpan(
                        text: 'banned',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: TerminalColors.red,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' and as a result you have been banned from Boot.\n\n',
                      ),
                      const TextSpan(
                        text:
                            '• You cannot access anything in Boot until you are unbanned\n',
                      ),
                      const TextSpan(
                        text:
                            '• Contact the Hackatime Fraud Department if you believe this is a mistake\n\n',
                      ),
                      TextSpan(
                        text: 'Naughty Naughty :(',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                'boot ~ ${UserService.currentUser?.username}@ysws',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated welcome text
          AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              String displayText = _welcomeText.substring(
                0,
                _typewriterAnimation.value,
              );
              return RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '\$ echo "',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                    TextSpan(
                      text: displayText,
                      style: textTheme.headlineMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '"',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          Text(
            'Build your OS, Get Hardware to run it.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTestButtons(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.bug_report, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Notification Tests',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    GlobalNotificationService.instance.showError(
                      'This is a test error notification',
                      persistent: false,
                    );
                  },
                  icon: Icon(Symbols.error, size: 18),
                  label: Text('Error'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    GlobalNotificationService.instance.showWarning(
                      'This is a test warning notification',
                    );
                  },
                  icon: Icon(Symbols.warning, size: 18),
                  label: Text('Warning'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.tertiaryContainer,
                    foregroundColor: colorScheme.onTertiaryContainer,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    GlobalNotificationService.instance.showInfo(
                      'This is a test info notification',
                    );
                  },
                  icon: Icon(Symbols.info, size: 18),
                  label: Text('Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    GlobalNotificationService.instance.showSuccess(
                      'This is a test success notification',
                    );
                  },
                  icon: Icon(Symbols.check_circle, size: 18),
                  label: Text('Success'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    GlobalNotificationService.instance.showPromo(
                      'This is a promotional notification with an action!',
                      actionLabel: 'Learn More',
                      onActionTap: () {
                        GlobalNotificationService.instance.showSuccess(
                          'Action button clicked!',
                        );
                      },
                    );
                  },
                  icon: Icon(Symbols.campaign, size: 18),
                  label: Text('Promo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    GlobalNotificationService.instance.showError(
                      'This error will stay in history until you clear it',
                      persistent: true,
                    );
                  },
                  icon: Icon(Symbols.push_pin, size: 18),
                  label: Text('Persistent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatus(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.monitor_heart, color: colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'System Status',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final children = [
                  _buildStatusItem(
                    'User',
                    UserService.currentUser?.username ?? 'Unknown',
                    Symbols.person,
                    colorScheme.secondary,
                    colorScheme,
                    textTheme,
                  ),
                  _buildStatusItem(
                    'Status',
                    _isHackatimeBanned ? 'ERROR' : 'READY',
                    _isHackatimeBanned ? Symbols.error : Symbols.check_circle,
                    _isHackatimeBanned
                        ? TerminalColors.red
                        : colorScheme.primary,
                    colorScheme,
                    textTheme,
                  ),
                ];
                if (constraints.maxWidth < Responsive.small) {
                  return Column(
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        children[i],
                        if (i < children.length - 1) const SizedBox(height: 16),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 16),
                    Expanded(child: children[1]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(ColorScheme colorScheme, TextTheme textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          // Side-by-side layout for wide screens
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMyOSesColumn(colorScheme, textTheme)),
            ],
          );
        } else {
          // Stacked layout for narrow screens
          return Column(children: [_buildMyOSesColumn(colorScheme, textTheme)]);
        }
      },
    );
  }

  Widget _buildMyOSesColumn(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Symbols.memory, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'My OSes',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingProjects)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_userProjects.isEmpty)
          Card(
            color: colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.add_circle,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No projects yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start building your OS!',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _userProjects.length,
              itemBuilder: (context, index) {
                final project = _userProjects[index];
                return _buildProjectCard(project, colorScheme, textTheme);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProjectCard(
    Project project,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: colorScheme.surfaceContainer,
        elevation: 2,
        child: InkWell(
          onTap: () => NavigationService.openProject(project, context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Symbols.terminal,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            project.level.toUpperCase(),
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    project.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Symbols.favorite, size: 16, color: TerminalColors.red),
                    const SizedBox(width: 4),
                    Text(
                      '${project.likes}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ProjectService.getStatusColor(
                          project.status,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: ProjectService.getStatusColor(project.status),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        project.status.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: ProjectService.getStatusColor(project.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationGrid(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Symbols.terminal, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Available Commands',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive columns based on screen width
            int columns;
            if (constraints.maxWidth > 800) {
              columns = 3; // Desktop
            } else if (constraints.maxWidth > 600) {
              columns = 2; // Tablet
            } else {
              columns = 1; // Mobile
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildNavigationCard(
                  title: 'Projects',
                  subtitle: 'See all your projects',
                  icon: Symbols.construction,
                  command: './build.sh',
                  color: colorScheme.primary,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () => NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.project,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  maxWidth:
                      (constraints.maxWidth - (12 * (columns - 1))) / columns,
                ),
                _buildNavigationCard(
                  title: 'TEST',
                  subtitle: 'Test your OS in a VM',
                  icon: Symbols.experiment,
                  command: './test.sh',
                  color: colorScheme.secondary,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () => NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.test,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  maxWidth:
                      (constraints.maxWidth - (12 * (columns - 1))) / columns,
                ),
                _buildNavigationCard(
                  title: 'EXPLORE',
                  subtitle: 'Browse projects',
                  icon: Symbols.explore,
                  command: './explore.sh',
                  color: TerminalColors.magenta,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () => NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.explore,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  maxWidth:
                      (constraints.maxWidth - (12 * (columns - 1))) / columns,
                ),
                _buildNavigationCard(
                  title: 'LEADERBOARD',
                  subtitle: 'Top rankings',
                  icon: Symbols.leaderboard,
                  command: './leaderboard.sh',
                  color: TerminalColors.red,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () => NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.leaderboard,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  maxWidth:
                      (constraints.maxWidth - (12 * (columns - 1))) / columns,
                ),
                _buildNavigationCard(
                  title: 'PROFILE',
                  subtitle: 'Your profile and stats',
                  icon: Symbols.account_circle,
                  command: './profile.sh',
                  color: TerminalColors.cyan,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    UserService.updateCurrentUser();
                    final user = UserService.currentUser;
                    if (user != null) {
                      NavigationService.openProfile(user, context);
                    }
                  },
                  maxWidth:
                      (constraints.maxWidth - (12 * (columns - 1))) / columns,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String command,
    required Color color,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
    required double maxWidth,
  }) {
    return SizedBox(
      width: maxWidth,
      child: Card(
        color: colorScheme.surfaceContainer,
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  command,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _ProfileCardWithHover extends StatefulWidget {
  final BootUser user;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _ProfileCardWithHover({
    required this.user,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  State<_ProfileCardWithHover> createState() => _ProfileCardWithHoverState();
}

class _ProfileCardWithHoverState extends State<_ProfileCardWithHover>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: widget.colorScheme.primary.withValues(
                  alpha: 0.2,
                ),
                backgroundImage: widget.user.profilePicture.isNotEmpty
                    ? NetworkImage(widget.user.profilePicture)
                    : null,
                child: widget.user.profilePicture.isEmpty
                    ? Text(
                        widget.user.username.isNotEmpty
                            ? widget.user.username[0].toUpperCase()
                            : '?',
                        style: widget.textTheme.titleLarge?.copyWith(
                          color: widget.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.username,
                      style: widget.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: TerminalColors.yellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: TerminalColors.yellow.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.toll,
                            size: 14,
                            color: TerminalColors.yellow,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.user.bootCoins}',
                            style: widget.textTheme.bodySmall?.copyWith(
                              color: TerminalColors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_animation.value, 0),
                    child: Icon(
                      Symbols.chevron_right,
                      color: widget.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
