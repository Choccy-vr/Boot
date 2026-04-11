import 'package:flutter/material.dart';
import '/services/Projects/Project.dart';
import '/services/Projects/project_service.dart';
import '/services/navigation/navigation_service.dart';
import '/theme/responsive.dart';
import '/theme/terminal_theme.dart';
import '/widgets/shared_navigation_rail.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  // Most Time tab state
  List<Project> _mostTimeProjects = [];
  bool _isLoadingMostTime = false;

  @override
  void initState() {
    super.initState();
    _loadMostTime();
  }

  Future<void> _loadMostTime() async {
    if (_isLoadingMostTime) return;

    setState(() {
      _isLoadingMostTime = true;
    });

    try {
      final projects = await ProjectService.getTopProjectsByTime(limit: 10);

      setState(() {
        _mostTimeProjects = projects;
        _isLoadingMostTime = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMostTime = false;
      });
      _showErrorSnackbar('Failed to load most time projects: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _refreshMostTime() async {
    await _loadMostTime();
  }

  Future<void> _navigateToProject(Project project) async {
    await NavigationService.openProject(project, context);
    if (!mounted) return;
    await _refreshMostTime();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SharedNavigationRail(
      showAppBar: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Leaderboard',
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          backgroundColor: colorScheme.surfaceContainerLow,
          elevation: 1,
        ),
        body: _buildMostTimeTab(colorScheme, textTheme),
      ),
    );
  }

  Widget _buildMostTimeTab(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _refreshMostTime,
      child: _mostTimeProjects.isEmpty && _isLoadingMostTime
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading leaderboard...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _mostTimeProjects.isEmpty
          ? _buildEmptyState(
              icon: Icons.schedule,
              title: 'No Projects Yet',
              subtitle: 'Start tracking your development time!',
              colorScheme: colorScheme,
              textTheme: textTheme,
            )
          : ListView.builder(
              padding: Responsive.pagePadding(context),
              itemCount: _mostTimeProjects.length,
              itemBuilder: (context, index) {
                return _buildLeaderboardCard(
                  project: _mostTimeProjects[index],
                  rank: index + 1,
                  primaryStat: _mostTimeProjects[index].readableTime,
                  primaryIcon: Icons.schedule,
                  primaryColor: TerminalColors.cyan,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 72, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 24),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard({
    required Project project,
    required int rank,
    required String primaryStat,
    required IconData primaryIcon,
    required Color primaryColor,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    // Special styling for top 3
    Color? rankColor;
    IconData? medalIcon;
    if (rank == 1) {
      rankColor = TerminalColors.yellow;
      medalIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400];
      medalIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      rankColor = Colors.brown[400];
      medalIcon = Icons.military_tech;
    }

    return Card(
      color: colorScheme.surfaceContainer,
      elevation: rank <= 3 ? 4 : 2,
      margin: EdgeInsets.only(bottom: Responsive.spacing(context)),
      child: InkWell(
        onTap: () => _navigateToProject(project),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: rank <= 3
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: rankColor!.withValues(alpha: 0.5),
                    width: 2,
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        rankColor?.withValues(alpha: 0.2) ??
                        colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    border: rankColor != null
                        ? Border.all(color: rankColor, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: medalIcon != null
                        ? Icon(medalIcon, color: rankColor, size: 28)
                        : Text(
                            '#$rank',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Project image
                if (project.imageURL.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      project.imageURL,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image,
                          color: colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.code,
                      color: colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 16),

                // Project info
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
                      const SizedBox(height: 4),
                      Text(
                        project.description,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.schedule,
                            label: project.readableTime,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            icon: Icons.emoji_events,
                            label: '${project.challengeIds.length}',
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Primary stat highlight
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(primaryIcon, color: primaryColor, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        primaryStat,
                        style: textTheme.titleLarge?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
