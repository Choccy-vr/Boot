import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/theme/terminal_theme.dart';
import '/services/supabase/DB/supabase_db.dart';
import '/services/users/User.dart';
import '../../services/navigation/navigation_service.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage>
    with SingleTickerProviderStateMixin {
  AnimationController? _refreshController;

  @override
  void dispose() {
    _refreshController?.dispose();
    super.dispose();
  }

  String timeAgoSinceDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    }
  }

  bool _isGridView = true;
  List<Project> _projects = [];

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status.toLowerCase()) {
      case 'building':
        return TerminalColors.yellow;
      case 'reviewing':
        return TerminalColors.cyan;
      case 'voting':
        return TerminalColors.green;
      case 'error':
        return TerminalColors.red;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  Future<List<Project>> _getProjects(String userID) async {
    final response = await SupabaseDB.GetMultipleRowData(
      table: 'projects',
      column: 'owner',
      columnValue: [userID],
    );
    if (response.isEmpty) return [];
    return response.map<Project>((row) => Project.fromRow(row)).toList();
  }

  void _openProject(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Row(
          children: [
            Text(
              project.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${project.status}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getStatusColor(
                  project.status,
                  Theme.of(context).colorScheme,
                ),
              ),
            ),
            Text(
              'Last modified: ${timeAgoSinceDate(project.lastModified)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening ${project.title}...')),
              );
            },
            child: Text('Open Project'),
          ),
        ],
      ),
    );
  }

  void _showCreateProjectDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Row(
          children: [
            Icon(Symbols.add, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Create New Project',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'MyAwesome OS',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'A brief description of your OS project...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                /*_createProject(
                  titleController.text.trim(),
                  descriptionController.text.trim(),
                );*/
                Navigator.pop(context);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  /*void _createProject(String title, String description) {
    setState(() {
      _projects.insert(
        0,
        Project(
          title: title,
          description: description.isNotEmpty
              ? description
              : 'No description provided',
          status: 'Building',
          lastModified: 'Just now',
          icon: Symbols.computer,
          thumbnailColor: TerminalColors.darkGray,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Project "$title" created successfully!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }*/

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
                'boot@hackathon:~/projects',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$ ls -la',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
          ),
          const SizedBox(height: 4),
          Text(
            'total ${_projects.length} projects',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsContent(ColorScheme colorScheme, TextTheme textTheme) {
    if (_projects.isEmpty) {
      return _buildEmptyState(colorScheme, textTheme);
    }

    return _isGridView
        ? _buildProjectsGrid(colorScheme, textTheme)
        : _buildProjectsList(colorScheme, textTheme);
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.folder_open,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No projects found',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first OS project to get started!',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateProjectDialog,
            icon: Icon(Symbols.add),
            label: Text('Create Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsGrid(ColorScheme colorScheme, TextTheme textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        double cardWidth;

        if (constraints.maxWidth > 1200) {
          columns = 4;
        } else if (constraints.maxWidth > 800) {
          columns = 3;
        } else if (constraints.maxWidth > 600) {
          columns = 2;
        } else {
          columns = 1;
        }

        cardWidth = (constraints.maxWidth - (16 * (columns - 1))) / columns;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: cardWidth > 300 ? 1.2 : 1.0,
          ),
          itemCount: _projects.length,
          itemBuilder: (context, index) {
            return _buildProjectCard(_projects[index], colorScheme, textTheme);
          },
        );
      },
    );
  }

  Widget _buildProjectsList(ColorScheme colorScheme, TextTheme textTheme) {
    return ListView.separated(
      itemCount: _projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildProjectListItem(_projects[index], colorScheme, textTheme);
      },
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
      child: InkWell(
        onTap: () => _openProject(project),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  project.imageURL,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Symbols.broken_image,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                project.title,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        project.status,
                        colorScheme,
                      ).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getStatusColor(project.status, colorScheme),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      project.status,
                      style: textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(project.status, colorScheme),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgoSinceDate(project.lastModified),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
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

  Widget _buildProjectListItem(
    Project project,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      elevation: 1,
      child: InkWell(
        onTap: () => _openProject(project),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                child: Image.network(
                  project.imageURL,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Symbols.broken_image,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.title,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              project.status,
                              colorScheme,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(
                                project.status,
                                colorScheme,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            project.status,
                            style: textTheme.bodySmall?.copyWith(
                              color: _getStatusColor(
                                project.status,
                                colorScheme,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last modified: ${timeAgoSinceDate(project.lastModified)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final userId = UserService.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    final projects = await _getProjects(userId);
    if (!mounted) return;

    setState(() {
      _projects = projects;
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
            Icon(Symbols.construction, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Projects',
              style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 1,
        actions: [
          AnimatedBuilder(
            animation: _refreshController!,
            builder: (context, child) {
              return Transform.rotate(
                angle: (_refreshController?.value ?? 0) * 6.28319, // 2 * pi
                child: child,
              );
            },
            child: IconButton(
              icon: Icon(Symbols.refresh, color: colorScheme.onSurface),
              onPressed: () async {
                if (!(_refreshController?.isAnimating ?? false)) {
                  _refreshController?.forward(from: 0);
                  await _fetchProjects();
                }
              },
              tooltip: 'Refresh',
            ),
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Symbols.view_list : Symbols.grid_view,
              color: colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              NavigationService.navigateTo(
                context: context,
                destination: AppDestination.createProject,
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            },
            icon: Icon(Symbols.add, size: 18),
            label: Text('Create Project'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTerminalHeader(colorScheme, textTheme),
            const SizedBox(height: 24),
            Expanded(child: _buildProjectsContent(colorScheme, textTheme)),
          ],
        ),
      ),
    );
  }
}

class Project {
  final String title;
  final String description;
  final String imageURL;
  final String githubRepo;
  final double time;
  final int likes;
  final String owner;
  final DateTime createdAt;
  final DateTime lastModified;
  final bool awaitingReview;
  final bool reviewed;
  final String level;
  final int id;
  final String status;
  final String hackatimeProjects;

  Project({
    required this.title,
    required this.description,
    required this.reviewed,
    required this.lastModified,
    required this.imageURL,
    required this.githubRepo,
    required this.time,
    required this.likes,
    required this.owner,
    required this.createdAt,
    required this.awaitingReview,
    required this.level,
    required this.id,
    required this.status,
    required this.hackatimeProjects,
  });

  factory Project.fromRow(Map<String, dynamic> row) {
    return Project(
      id: row['id'] ?? 0,
      title: row['name'] ?? 'Untitled Project',
      description: row['description'] ?? 'No description provided',
      imageURL: row['image_url'] ?? '',
      githubRepo: row['github_repo'] ?? '',
      time: (row['total_time'] ?? 0.0).toDouble(),
      likes: row['total_likes'] ?? 0,
      owner: row['owner'] ?? 'unknown',
      createdAt: DateTime.parse(row['created_at'] ?? DateTime.now().toString()),
      lastModified: DateTime.parse(
        row['updated_at'] ?? DateTime.now().toString(),
      ),
      awaitingReview: row['awaiting_review'] ?? false,
      level: row['level'] ?? 'unknown',
      status: row['status'] ?? 'unknown',
      reviewed: row['reviewed'] ?? false,
      hackatimeProjects: row['hackatime_projects'] ?? '',
    );
  }
}
