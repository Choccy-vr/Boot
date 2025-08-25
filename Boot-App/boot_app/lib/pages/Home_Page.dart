import 'package:flutter/material.dart';
import 'dart:io';
import '/theme/terminal_theme.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/services/navigation_service.dart';
import '/services/users/User.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  final String _welcomeText = "Welcome to Boot Hackathon 2025";

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Terminal Header
              _buildTerminalHeader(colorScheme, textTheme),
              const SizedBox(height: 24),

              // System Status
              _buildSystemStatus(colorScheme, textTheme),
              const SizedBox(height: 24),

              // Main Navigation Grid
              _buildNavigationGrid(colorScheme, textTheme),
              const SizedBox(height: 24),

              // Quick Stats
              _buildQuickStats(colorScheme, textTheme),
            ],
          ),
        ),
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
                'boot-terminal ~ ${UserService.currentUser?.username}@hackathon',
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
            'Build your OS. Winter 2025.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
                Text(
                  'System Status',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'Platform',
                    Platform.operatingSystem.toUpperCase(),
                    Symbols.computer,
                    colorScheme.primary,
                    colorScheme,
                    textTheme,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'User',
                    UserService.currentUser?.username ?? 'Unknown',
                    Symbols.person,
                    colorScheme.secondary,
                    colorScheme,
                    textTheme,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'Status',
                    'READY',
                    Symbols.check_circle,
                    colorScheme.primary,
                    colorScheme,
                    textTheme,
                  ),
                ),
              ],
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

  Widget _buildNavigationGrid(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '> Available Commands',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.bold,
          ),
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
                    destination: 'build',
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
                    destination: 'test',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  maxWidth:
                      (constraints.maxWidth - (12 * (columns - 1))) / columns,
                ),
                _buildNavigationCard(
                  title: 'VOTE',
                  subtitle: 'Vote on projects',
                  icon: Symbols.how_to_vote,
                  command: './vote.sh',
                  color: colorScheme.tertiary,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () => NavigationService.navigateTo(
                    context: context,
                    destination: 'vote',
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
                    destination: 'explore',
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
                    destination: 'leaderboard',
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
                  onTap: () => NavigationService.navigateTo(
                    context: context,
                    destination: 'profile',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
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

  Widget _buildQuickStats(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.analytics, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Quick Stats',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Projects',
                    '1,247',
                    Symbols.folder,
                    colorScheme.primary,
                    colorScheme,
                    textTheme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Active Builders',
                    '89',
                    Symbols.group,
                    colorScheme.secondary,
                    colorScheme,
                    textTheme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Votes Cast',
                    '5,602',
                    Symbols.how_to_vote,
                    Colors.purple,
                    colorScheme,
                    textTheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
