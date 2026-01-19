import 'package:boot_app/theme/terminal_theme.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/services/users/Boot_User.dart';
import '/services/Projects/Project.dart';
import '/services/Projects/project_service.dart';
import '/services/devlog/Devlog.dart';
import '/services/devlog/devlog_service.dart';
import '/services/navigation/navigation_service.dart';
import '/services/users/User.dart';
import '/theme/responsive.dart';
import '/widgets/shared_navigation_rail.dart';

class ProfilePage extends StatefulWidget {
  final BootUser user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Project> _userProjects = [];
  List<Devlog> _userDevlogs = [];
  List<Project> _likedProjects = [];
  bool _isLoadingProjects = true;
  bool _isLoadingDevlogs = true;
  bool _isLoadingLikedProjects = true;
  bool _isHoveringProfilePic = false;
  bool _isEditingBio = false;
  bool _isEditingUsername = false;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool get _isOwnProfile => UserService.currentUser?.id == widget.user.id;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    await _loadUserProjects();
    await _loadUserDevlogs();
  }

  Future<void> _loadUserProjects() async {
    try {
      final projects = await ProjectService.getProjects(widget.user.id);
      if (mounted) {
        setState(() {
          _userProjects = projects;
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  Future<void> _loadUserDevlogs() async {
    try {
      List<Devlog> allDevlogs = [];
      for (final project in _userProjects) {
        final devlogs = await DevlogService.getDevlogsByProjectId(
          project.id.toString(),
        );
        allDevlogs.addAll(devlogs);
      }

      // Sort devlogs by creation date (newest first)
      allDevlogs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _userDevlogs = allDevlogs;
          _isLoadingDevlogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDevlogs = false;
        });
      }
    }
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
          title: Text(
            '${widget.user.username}\'s Profile',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.primary,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: Responsive.pagePadding(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= Responsive.medium;

              if (isWide) {
                // Wide layout: side-by-side
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - Profile Info
                    SizedBox(
                      width: Responsive.value(
                        context: context,
                        smallValue: 280.0,
                        mediumValue: 320.0,
                        largeValue: 360.0,
                      ),
                      child: Column(
                        children: [
                          _buildProfileCard(colorScheme, textTheme),
                          SizedBox(height: Responsive.spacing(context)),
                          _buildCompactStatsCard(colorScheme, textTheme),
                        ],
                      ),
                    ),
                    SizedBox(width: Responsive.spacing(context) * 1.5),
                    // Right Column - Content Feed
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopProjectsSection(colorScheme, textTheme),
                          SizedBox(height: Responsive.spacing(context)),
                          _buildRecentDevlogsSection(colorScheme, textTheme),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Narrow layout: stacked
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileCard(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildCompactStatsCard(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildTopProjectsSection(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildRecentDevlogsSection(colorScheme, textTheme),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopProjectsSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.folder_open, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Projects',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_userProjects.length} total',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoadingProjects)
              Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            else if (_userProjects.isEmpty)
              _buildEmptyState(
                'No projects yet',
                'This user hasn\'t created any projects.',
                Symbols.folder_open,
                colorScheme,
                textTheme,
              )
            else
              Column(
                children: _userProjects
                    .map(
                      (project) => _buildProjectListItem(
                        project,
                        colorScheme,
                        textTheme,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDevlogsSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.article, color: colorScheme.secondary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Devlogs',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_userDevlogs.length} total',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoadingDevlogs)
              Center(
                child: CircularProgressIndicator(color: colorScheme.secondary),
              )
            else if (_userDevlogs.isEmpty)
              _buildEmptyState(
                'No devlogs yet',
                'This user hasn\'t written any devlogs.',
                Symbols.article,
                colorScheme,
                textTheme,
              )
            else
              Column(
                children: _userDevlogs
                    .map(
                      (devlog) =>
                          _buildDevlogListItem(devlog, colorScheme, textTheme),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Picture
            MouseRegion(
              onEnter: _isOwnProfile
                  ? (_) => setState(() => _isHoveringProfilePic = true)
                  : null,
              onExit: _isOwnProfile
                  ? (_) => setState(() => _isHoveringProfilePic = false)
                  : null,
              child: GestureDetector(
                onTap: _isOwnProfile ? _handleProfilePictureEdit : null,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(77),
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(47),
                        child: widget.user.profilePicture.isNotEmpty
                            ? Image.network(
                                widget.user.profilePicture,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Symbols.person,
                                    color: colorScheme.primary,
                                    size: 50,
                                  );
                                },
                              )
                            : Icon(
                                Symbols.person,
                                color: colorScheme.primary,
                                size: 50,
                              ),
                      ),
                      if (_isOwnProfile && _isHoveringProfilePic)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(47),
                          ),
                          child: Icon(
                            Symbols.camera_alt,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Username
            if (_isEditingUsername && _isOwnProfile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(77),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            hintText: 'Enter your username...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                          ),
                          style: textTheme.headlineMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: Icon(
                              Symbols.check,
                              color: colorScheme.primary,
                            ),
                            onPressed: _saveUsername,
                            tooltip: 'Save',
                          ),
                          IconButton(
                            icon: Icon(Symbols.close, color: colorScheme.error),
                            onPressed: _cancelUsernameEdit,
                            tooltip: 'Cancel',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              MouseRegion(
                cursor: _isOwnProfile
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: _isOwnProfile ? _startUsernameEdit : null,
                  child: Text(
                    widget.user.username,
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 12),

            //bio
            if (_isEditingBio && _isOwnProfile)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter your bio...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(Symbols.check, color: colorScheme.primary),
                          onPressed: _saveBio,
                          tooltip: 'Save',
                        ),
                        IconButton(
                          icon: Icon(Symbols.close, color: colorScheme.error),
                          onPressed: _cancelBioEdit,
                          tooltip: 'Cancel',
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              MouseRegion(
                cursor: _isOwnProfile
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: _isOwnProfile ? _startBioEdit : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(minHeight: 60),
                    decoration: BoxDecoration(
                      color:
                          (widget.user.bio.isNotEmpty &&
                              widget.user.bio != "Nothing Yet")
                          ? colorScheme.primaryContainer.withAlpha(77)
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (widget.user.bio.isNotEmpty &&
                                widget.user.bio != "Nothing Yet")
                            ? colorScheme.primary.withAlpha(77)
                            : colorScheme.outline,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (widget.user.bio.isNotEmpty &&
                                widget.user.bio != "Nothing Yet")
                            ? widget.user.bio
                            : _isOwnProfile
                            ? 'Click to add bio'
                            : 'No bio yet',
                        style: textTheme.bodyMedium?.copyWith(
                          color:
                              (widget.user.bio.isNotEmpty &&
                                  widget.user.bio != "Nothing Yet")
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontStyle:
                              (widget.user.bio.isEmpty ||
                                  widget.user.bio == "Nothing Yet")
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Symbols.event,
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Joined ${_formatDate(widget.user.createdAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatsCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.analytics, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Stats',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats in 2x2 grid
            Row(
              children: [
                Expanded(
                  child: _buildCompactStatItem(
                    'Projects',
                    widget.user.totalProjects.toString(),
                    Symbols.folder_open,
                    colorScheme.primary,
                    colorScheme,
                    textTheme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStatItem(
                    'Devlogs',
                    widget.user.devlogs.toString(),
                    Symbols.article,
                    colorScheme.secondary,
                    colorScheme,
                    textTheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactStatItem(
                    'Boot Coins',
                    widget.user.bootCoins.toString(),
                    Symbols.toll,
                    TerminalColors.yellow,
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

  Widget _buildProjectListItem(
    Project project,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(77)),
      ),
      child: InkWell(
        onTap: () => NavigationService.openProject(project, context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Project Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: project.imageURL.isNotEmpty
                      ? Image.network(
                          project.imageURL,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Symbols.broken_image,
                            color: colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        )
                      : Icon(
                          Symbols.folder_open,
                          color: colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Project Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: textTheme.titleSmall?.copyWith(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Time/Likes
              Column(
                children: [
                  if (project.readableTime.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        project.readableTime,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
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
    );
  }

  Widget _buildDevlogListItem(
    Devlog devlog,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _navigateToProjectFromDevlog(devlog),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      devlog.title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    timeAgoSinceDate(devlog.createdAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                devlog.description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
              if (devlog.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDevlogMediaViewer(devlog.mediaUrls, colorScheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevlogMediaViewer(
    List<String> mediaUrls,
    ColorScheme colorScheme,
  ) {
    return _DevlogMediaViewer(mediaUrls: mediaUrls, colorScheme: colorScheme);
  }

  Widget _buildCompactStatItem(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withAlpha(77)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
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
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String timeAgoSinceDate(DateTime date) {
    final now = DateTime.now().toUtc();
    final utcDate = date.isUtc ? date : date.toUtc();
    final difference = now.difference(utcDate);
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

  void _handleProfilePictureEdit() async {
    try {
      final profilePic = await UserService.uploadProfilePic(context);
      if (!mounted) return;
      setState(() {
        widget.user.profilePicture = profilePic;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _startBioEdit() {
    setState(() {
      _isEditingBio = true;
      _bioController.text = widget.user.bio == "Nothing Yet"
          ? ""
          : widget.user.bio;
    });
  }

  void _startUsernameEdit() {
    setState(() {
      _isEditingUsername = true;
      _usernameController.text = widget.user.username;
    });
  }

  void _cancelBioEdit() {
    setState(() {
      _isEditingBio = false;
      _bioController.clear();
    });
  }

  void _cancelUsernameEdit() {
    setState(() {
      _isEditingUsername = false;
      _usernameController.clear();
    });
  }

  Future<void> _saveBio() async {
    try {
      // Update the user's bio
      final updatedUser = widget.user;
      updatedUser.bio = _bioController.text.trim().isEmpty
          ? "Nothing Yet"
          : _bioController.text.trim();

      // Update in the current user service if it's the current user
      if (_isOwnProfile) {
        UserService.currentUser?.bio = updatedUser.bio;
        await UserService.updateUser();
      }

      if (!mounted) return;
      setState(() {
        _isEditingBio = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bio updated successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update bio: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _saveUsername() async {
    try {
      final newUsername = _usernameController.text.trim();

      if (newUsername.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Username cannot be empty!'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      // Update the user's username
      final updatedUser = widget.user;
      updatedUser.username = newUsername;

      // Update in the current user service if it's the current user
      if (_isOwnProfile) {
        UserService.currentUser?.username = newUsername;
        await UserService.updateUser();
      }

      if (!mounted) return;
      setState(() {
        _isEditingUsername = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username updated successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update username: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _navigateToProjectFromDevlog(Devlog devlog) {
    // Find the project that contains this devlog
    try {
      final project = _userProjects.firstWhere(
        (project) => project.id.toString() == devlog.projectId.toString(),
      );
      NavigationService.openProject(project, context);
    } catch (e) {
      // Error finding project: $e
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Project not found for this devlog (ID: ${devlog.projectId})',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _DevlogMediaViewer extends StatefulWidget {
  final List<String> mediaUrls;
  final ColorScheme colorScheme;

  const _DevlogMediaViewer({
    required this.mediaUrls,
    required this.colorScheme,
  });

  @override
  State<_DevlogMediaViewer> createState() => _DevlogMediaViewerState();
}

class _DevlogMediaViewerState extends State<_DevlogMediaViewer> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Media container that adjusts to image size with constraints
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(
              minHeight: 150,
              maxHeight: 500,
              maxWidth: double.infinity,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Stack(
              children: [
                // Main image with intrinsic dimensions but constrained
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 150, maxHeight: 500),
                  child: Image.network(
                    widget.mediaUrls[currentIndex],
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: double.infinity,
                      color: widget.colorScheme.errorContainer,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Symbols.broken_image,
                              size: 48,
                              color: widget.colorScheme.error,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load media',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: widget.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Navigation arrows (only show if multiple images)
                if (widget.mediaUrls.length > 1) ...[
                  // Previous arrow
                  if (currentIndex > 0)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                currentIndex--;
                              });
                            },
                            icon: Icon(
                              Symbols.chevron_left,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),

                  // Next arrow
                  if (currentIndex < widget.mediaUrls.length - 1)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                currentIndex++;
                              });
                            },
                            icon: Icon(
                              Symbols.chevron_right,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),

        // Media indicators and counter (only show if multiple images)
        if (widget.mediaUrls.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dot indicators
              ...List.generate(widget.mediaUrls.length, (index) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == currentIndex
                        ? widget.colorScheme.primary
                        : widget.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                );
              }),
              const SizedBox(width: 12),
              // Counter text
              Text(
                '${currentIndex + 1}/${widget.mediaUrls.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
