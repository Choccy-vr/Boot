import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../services/auth/Auth.dart';
import '/services/navigation/navigation_service.dart';
import '/services/users/User.dart';
import '/services/users/Boot_User.dart';
import '/theme/terminal_theme.dart';

/// A shared navigation rail widget that can be used across all pages.
/// It overlays content when expanded instead of pushing it.
class SharedNavigationRail extends StatefulWidget {
  final Widget child;
  final bool showAppBar;
  final List<Widget>? appBarActions;

  const SharedNavigationRail({
    super.key,
    required this.child,
    this.showAppBar = true,
    this.appBarActions,
  });

  @override
  State<SharedNavigationRail> createState() => _SharedNavigationRailState();
}

class _SharedNavigationRailState extends State<SharedNavigationRail> {
  bool _isRailExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final collapsedRailWidth = 72.0;
    final expandedRailWidth = 240.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: colorScheme.surfaceContainerLowest,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: widget.appBarActions,
            )
          : null,
      body: Stack(
        children: [
          // Main content with fixed left padding for collapsed rail
          Positioned.fill(left: collapsedRailWidth, child: widget.child),
          // Navigation rail (overlays when expanded)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isRailExpanded = true),
              onExit: (_) => setState(() => _isRailExpanded = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isRailExpanded ? expandedRailWidth : collapsedRailWidth,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  border: Border(
                    right: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  boxShadow: _isRailExpanded
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(2, 0),
                          ),
                        ]
                      : null,
                ),
                child: _buildRailContent(colorScheme, textTheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentRoute(String routePath) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == null) return false;

    // Check for exact match or route prefix
    if (currentRoute == routePath) return true;

    // Handle special cases like /projects/:id matching /projects
    if (routePath == '/projects' && currentRoute.startsWith('/projects/')) {
      return true;
    }
    if (routePath == '/user' && currentRoute.startsWith('/user/')) {
      return true;
    }

    return false;
  }

  Widget _buildRailContent(ColorScheme colorScheme, TextTheme textTheme) {
    final user = UserService.currentUser;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: _isRailExpanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.terminal,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Boot',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Icon(
                    Symbols.terminal,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
        ),
        // Navigation items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildRailItem(
                icon: Symbols.home,
                title: 'Dashboard',
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () {
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.home,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              ),
              _buildRailItem(
                icon: Symbols.construction,
                title: 'My Projects',
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () {
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.project,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              ),
              _buildRailItem(
                icon: Symbols.explore,
                title: 'Explore',
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () {
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.explore,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              ),
              _buildRailItem(
                icon: Symbols.leaderboard,
                title: 'Leaderboard',
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () {
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.leaderboard,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              ),
              _buildRailItem(
                icon: Symbols.mountain_flag,
                title: 'Bounties',
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () {
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.challenges,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              ),
              _buildRailItem(
                icon: Symbols.storefront,
                title: 'Shop',
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () {
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.shop,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
              ),
              if (user?.role == UserRole.reviewer ||
                  user?.role == UserRole.admin ||
                  user?.role == UserRole.owner)
                _buildRailItem(
                  icon: Symbols.grading,
                  title: 'Reviewer Center',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    NavigationService.navigateTo(
                      context: context,
                      destination: AppDestination.reviewer,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  },
                ),
              if (user?.role == UserRole.admin || user?.role == UserRole.owner)
                _buildRailItem(
                  icon: Symbols.admin_panel_settings,
                  title: 'Admin Panel',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    NavigationService.navigateTo(
                      context: context,
                      destination: AppDestination.admin,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  },
                ),
            ],
          ),
        ),
        // Profile section
        if (user != null) _buildRailProfile(user, colorScheme, textTheme),
      ],
    );
  }

  Widget _buildRailItem({
    required IconData icon,
    required String title,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    final iconColor = colorScheme.primary;
    final textColor = colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              if (_isRailExpanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailProfile(
    BootUser user,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final hasProfileImage = user.profilePicture.isNotEmpty;

    // When collapsed, just show a centered avatar
    if (!_isRailExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: InkWell(
            onTap: () {
              NavigationService.navigateTo(
                context: context,
                destination: AppDestination.profile,
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: hasProfileImage
                    ? Colors.transparent
                    : colorScheme.primary.withValues(alpha: 0.2),
                backgroundImage: hasProfileImage
                    ? NetworkImage(user.profilePicture)
                    : null,
                child: hasProfileImage
                    ? null
                    : Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : '?',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded state with full profile card
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainer,
            colorScheme.surfaceContainerLowest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              NavigationService.navigateTo(
                context: context,
                destination: AppDestination.profile,
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: hasProfileImage
                          ? Colors.transparent
                          : colorScheme.primary.withValues(alpha: 0.2),
                      backgroundImage: hasProfileImage
                          ? NetworkImage(user.profilePicture)
                          : null,
                      child: hasProfileImage
                          ? null
                          : Text(
                              user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : '?',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.username,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: TerminalColors.yellow.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: TerminalColors.yellow.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Symbols.toll,
                                  size: 11,
                                  color: TerminalColors.yellow,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${user.bootCoins}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: TerminalColors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Authentication.signOut();
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.login,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
                icon: Icon(Symbols.logout, size: 16, color: TerminalColors.red),
                label: Text(
                  'Logout',
                  style: textTheme.bodySmall?.copyWith(
                    color: TerminalColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: TerminalColors.red.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
