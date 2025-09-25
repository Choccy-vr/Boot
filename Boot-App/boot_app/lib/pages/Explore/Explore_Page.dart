import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '/services/Projects/project.dart';
import '/services/Projects/project_service.dart';
import '/services/users/user.dart';
import '/pages/Projects/project_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // All Projects tab state
  List<Project> _allProjects = [];
  bool _isLoadingAllProjects = false;
  bool _hasMoreProjects = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  final ScrollController _allProjectsScrollController = ScrollController();

  // Liked Projects tab state
  List<Project> _likedProjects = [];
  bool _isLoadingLikedProjects = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllProjects();
    _loadLikedProjects();

    _allProjectsScrollController.addListener(() {
      if (_allProjectsScrollController.position.pixels >=
          _allProjectsScrollController.position.maxScrollExtent - 200) {
        _loadMoreProjects();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allProjectsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllProjects() async {
    if (_isLoadingAllProjects) return;

    setState(() {
      _isLoadingAllProjects = true;
    });

    try {
      final projects = await ProjectService.getAllProjects(
        limit: _pageSize,
        offset: 0,
      );

      setState(() {
        _allProjects = projects;
        _currentPage = 0;
        _hasMoreProjects = projects.length == _pageSize;
        _isLoadingAllProjects = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAllProjects = false;
      });
      _showErrorSnackbar('Failed to load projects: $e');
    }
  }

  Future<void> _loadMoreProjects() async {
    if (_isLoadingAllProjects || !_hasMoreProjects) return;

    setState(() {
      _isLoadingAllProjects = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final projects = await ProjectService.getAllProjects(
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      setState(() {
        _allProjects.addAll(projects);
        _currentPage = nextPage;
        _hasMoreProjects = projects.length == _pageSize;
        _isLoadingAllProjects = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAllProjects = false;
      });
      _showErrorSnackbar('Failed to load more projects: $e');
    }
  }

  Future<void> _loadLikedProjects() async {
    if (_isLoadingLikedProjects) return;

    setState(() {
      _isLoadingLikedProjects = true;
    });

    try {
      final likedProjectIds = UserService.currentUser?.likedProjects ?? [];
      final projects = await ProjectService.getLikedProjects(likedProjectIds);

      setState(() {
        _likedProjects = projects;
        _isLoadingLikedProjects = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLikedProjects = false;
      });
      _showErrorSnackbar('Failed to load liked projects: $e');
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

  Future<void> _refreshAllProjects() async {
    await _loadAllProjects();
  }

  Future<void> _refreshLikedProjects() async {
    await _loadLikedProjects();
  }

  void _navigateToProject(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailPage(project: project),
      ),
    ).then((_) {
      // Refresh data when returning from project page
      if (_tabController.index == 0) {
        _refreshAllProjects();
      } else {
        _refreshLikedProjects();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Symbols.explore, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Explore Projects',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Symbols.public), text: 'All Projects'),
            Tab(icon: Icon(Symbols.favorite), text: 'Liked Projects'),
          ],
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllProjectsTab(colorScheme, textTheme),
          _buildLikedProjectsTab(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildAllProjectsTab(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _refreshAllProjects,
      child: _allProjects.isEmpty && _isLoadingAllProjects
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading projects...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _allProjects.isEmpty
          ? _buildEmptyState(
              icon: Symbols.search_off,
              title: 'No Projects Found',
              subtitle: 'There are no projects to explore yet.',
              colorScheme: colorScheme,
              textTheme: textTheme,
            )
          : ListView.builder(
              controller: _allProjectsScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _allProjects.length + (_hasMoreProjects ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _allProjects.length) {
                  // Loading indicator for pagination
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                }

                return _buildProjectCard(
                  _allProjects[index],
                  colorScheme,
                  textTheme,
                );
              },
            ),
    );
  }

  Widget _buildLikedProjectsTab(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: _refreshLikedProjects,
      child: _likedProjects.isEmpty && _isLoadingLikedProjects
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading liked projects...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _likedProjects.isEmpty
          ? _buildEmptyState(
              icon: Symbols.favorite_border,
              title: 'No Liked Projects',
              subtitle: 'Projects you like will appear here.',
              colorScheme: colorScheme,
              textTheme: textTheme,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _likedProjects.length,
              itemBuilder: (context, index) {
                return _buildProjectCard(
                  _likedProjects[index],
                  colorScheme,
                  textTheme,
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

  Widget _buildProjectCard(
    Project project,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToProject(project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                            Symbols.image,
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
                        Symbols.code,
                        color: colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  const SizedBox(width: 16),
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
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Symbols.favorite,
                    label: '${project.likes}',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Symbols.schedule,
                    label: project.time > 0
                        ? '${project.time.toStringAsFixed(1)}h'
                        : '0h',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(project.status, colorScheme, textTheme),
                  const Spacer(),
                  Text(
                    _timeAgoSinceDate(project.createdAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
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

  Widget _buildStatusChip(
    String status,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    Color statusColor;
    statusColor = ProjectService.getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: textTheme.bodySmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _timeAgoSinceDate(DateTime date) {
    final now = DateTime.now().toUtc();
    final utcDate = date.isUtc ? date : date.toUtc();
    final difference = now.difference(utcDate);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }
}
