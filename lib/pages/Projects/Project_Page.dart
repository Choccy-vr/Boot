//Packages
import 'dart:io';
import 'package:boot_app/services/hackatime/hackatime_service.dart';
import 'package:boot_app/services/ships/ship_service.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';
//Theme Data

//Services
import '/services/Projects/Project.dart';
import '/services/Projects/project_service.dart';
import '/services/supabase/Storage/supabase_storage.dart';
import '/services/supabase/DB/functions/supabase_db_functions.dart';
import '../../services/devlog/Devlog.dart';
import '/services/devlog/devlog_service.dart';
import '/theme/responsive.dart';

class ProjectDetailPage extends StatefulWidget {
  final Project project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  AnimationController? _refreshController;
  late Project _project;
  List<Devlog> _devlogs = [];
  bool _isLoading = false;
  bool _isHovering = false;
  String owner = "";
  bool _isLiked = false;
  bool _isLiking = false;
  bool _showDevlogEditor = false;
  final TextEditingController _devlogTitleController = TextEditingController();
  final TextEditingController _devlogDescriptionController =
      TextEditingController();
  final List<String> _cachedMediaPaths = [];
  bool _isUploadingMedia = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadOwner();
    _loadDevlogs();
    _refreshController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _getTime();
    _userLiked();
  }

  Future<void> _loadOwner() async {
    final user = await UserService.getUserById(_project.owner);
    setState(() {
      owner = user?.username ?? '';
    });
  }

  Future<void> _loadDevlogs() async {
    try {
      final devlogs = await DevlogService.getDevlogsByProjectId(
        _project.id.toString(),
      );
      setState(() {
        _devlogs = devlogs;
      });
    } catch (e) {
      // Error loading devlogs: $e
    }
  }

  Future<void> _getTime() async {
    try {
      final updatedProject = await HackatimeService.getProjectTime(
        project: _project,
        userId: UserService.currentUser?.hackatimeID ?? 0,
        apiKey: UserService.currentUser?.hackatimeApiKey ?? '',
        context: context,
      );
      if (!mounted) return;
      setState(() {
        _project = updatedProject;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(context, 'Failed to get project time');
    }
  }

  Future<void> _userLiked() async {
    try {
      setState(() {
        _isLiked =
            UserService.currentUser?.likedProjects.contains(_project.id) ??
            false;
      });
    } catch (_) {}
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _refreshController?.dispose();
    _devlogTitleController.dispose();
    _devlogDescriptionController.dispose();
    super.dispose();
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

  Future<void> _handleLikeProject() async {
    if (_isLiking) return;
    try {
      setState(() => _isLiking = true);
      if (_isLiked) {
        await SupabaseDBFunctions.callDbFunction(
          functionName: 'decrement_likes',
          parameters: {'project_id': _project.id},
        );
        UserService.currentUser?.likedProjects.remove(_project.id);
        setState(() {
          _project.likes = (_project.likes - 1).clamp(0, 1 << 31);
          _isLiked = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You unliked ${_project.title}.')),
        );
      } else {
        await SupabaseDBFunctions.callDbFunction(
          functionName: 'increment_likes',
          parameters: {'project_id': _project.id},
        );
        UserService.currentUser?.likedProjects.add(_project.id);
        setState(() {
          _project.likes += 1;
          _isLiked = true;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('You liked ${_project.title}!')));
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(context, 'Failed to like/unlike project: $e');
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _handleOpenGitHubRepo() async {
    final url = Uri.parse(_project.githubRepo);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _handleCreateDevlog() async {
    setState(() {
      _showDevlogEditor = true;
    });
  }

  void _closeDevlogEditor() {
    setState(() {
      _showDevlogEditor = false;
      _devlogTitleController.clear();
      _devlogDescriptionController.clear();
      _cachedMediaPaths.clear();
    });
  }

  Future<void> _handleUploadDevlogMedia() async {
    setState(() {
      _isUploadingMedia = true;
    });

    try {
      final cachedFilePath = await DevlogService.cacheMediaFilePicker();
      if (cachedFilePath != 'User cancelled') {
        setState(() {
          _cachedMediaPaths.add(cachedFilePath);
          _isUploadingMedia = false;
        });
      } else {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploadingMedia = false;
      });
      if (!mounted) return;
      // Optionally show error message
      _showErrorSnackbar(context, 'Failed to upload media: $e');
    }
  }

  Future<void> _handleSaveDevlog() async {
    final newDevlog = await DevlogService.addDevlog(
      projectID: _project.id,
      title: _devlogTitleController.text,
      description: _devlogDescriptionController.text,
      cachedMediaUrls: _cachedMediaPaths,
    );
    setState(() {
      _devlogs.add(newDevlog);
    });
    _closeDevlogEditor();
  }

  bool _isOwner() {
    return UserService.currentUser?.id == _project.owner;
  }

  Future<void> _showShipConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Symbols.directions_boat, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Ship Your Project'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Before shipping your project, please ensure:',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRequirementItem(
                  'Project is in a working/testable state',
                  colorScheme,
                  textTheme,
                ),
                _buildRequirementItem(
                  'Added significant features or many smaller improvements',
                  colorScheme,
                  textTheme,
                ),
                _buildRequirementItem(
                  'Ready for community review',
                  colorScheme,
                  textTheme,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Once shipped, your project will be submitted for community review and voting.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleShipProject();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.directions_boat, size: 16),
                  const SizedBox(width: 4),
                  Text('Ship It!'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequirementItem(
    String text,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.check_circle, color: colorScheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _handleShipProject() async {
    try {
      await ShipService.addShip(
        project: _project.id,
        time: _project.timeDevlogs,
        // TODO: IMPORTANT: REMOVE AFTER TESTING
        approved: true,
      );

      _showShipSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ship project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showShipSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Symbols.celebration, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Congratulations!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Symbols.rocket_launch,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your project has been shipped!',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your project is now available for the community to review and vote on. Good luck!',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reload the page by refreshing the project data
                _reloadProjectData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text('Awesome!'),
            ),
          ],
        );
      },
    );
  }

  void _reloadProjectData() {
    // Refresh the project data to reflect the new status
    setState(() {
      _project.status = 'Shipped / Awaiting Review';
    });
  }

  String _getMediaTypeFromPath(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'image';
      case 'mp4':
        return 'video';
      case 'gif':
        return 'gif';
      default:
        return 'unknown';
    }
  }

  Future<void> _showStatusEditDialog() async {
    final predefinedStatuses = ['building', 'reviewing', 'voting', 'error'];
    String? selectedStatus;
    final TextEditingController customStatusController =
        TextEditingController();
    bool useCustomStatus = false;

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Symbols.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Project Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a predefined status:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: predefinedStatuses.map((status) {
                        final isSelected =
                            selectedStatus == status && !useCustomStatus;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedStatus = status;
                              useCustomStatus = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ProjectService.getStatusColor(
                                      status,
                                    ).withValues(alpha: 0.2)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? ProjectService.getStatusColor(status)
                                    : Theme.of(context).colorScheme.outline
                                          .withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              status,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: isSelected
                                        ? ProjectService.getStatusColor(status)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Or create a custom status:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customStatusController,
                      decoration: InputDecoration(
                        hintText: 'Enter custom status...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          useCustomStatus = value.isNotEmpty;
                          if (useCustomStatus) {
                            selectedStatus = value;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      (selectedStatus != null && selectedStatus!.isNotEmpty)
                      ? () {
                          Navigator.of(context).pop(selectedStatus);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text('Update Status'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Update the project status locally
        setState(() {
          _project.status = result;
        });

        // Update the project in the database
        await ProjectService.updateProject(_project);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project status updated to "$result"'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackbar(context, 'Failed to update status: $e');
      }
    }
  }

  Widget _buildDevlogEditor() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              _buildDevlogEditorHeader(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDevlogMediaSection(),
                      SizedBox(height: 24),
                      _buildDevlogTitleField(),
                      SizedBox(height: 24),
                      _buildDevlogDescriptionField(),
                    ],
                  ),
                ),
              ),
              _buildDevlogEditorFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevlogEditorHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.edit_note,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          SizedBox(width: 12),
          Text(
            'Create Devlog',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          IconButton(
            onPressed: _closeDevlogEditor,
            icon: Icon(
              Symbols.close,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildDevlogTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _devlogTitleController,
          maxLength: 80,
          decoration: InputDecoration(
            hintText: 'Enter devlog title...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevlogMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Media',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Spacer(),
            if (_cachedMediaPaths.isNotEmpty)
              Text(
                '${_cachedMediaPaths.length} file${_cachedMediaPaths.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              style: BorderStyle.solid,
            ),
          ),
          child: _cachedMediaPaths.isEmpty
              ? _buildMediaUploadArea()
              : _buildMediaCarousel(),
        ),
        if (_cachedMediaPaths.isNotEmpty) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleUploadDevlogMedia,
                  icon: Icon(Symbols.add, size: 16),
                  label: Text('Add More'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _cachedMediaPaths.clear();
                  });
                },
                icon: Icon(Symbols.delete, size: 16),
                label: Text('Clear All'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMediaUploadArea() {
    return InkWell(
      onTap: _handleUploadDevlogMedia,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: _isUploadingMedia
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Uploading...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.cloud_upload,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Upload Image, Video, or GIF',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Click to browse files',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMediaCarousel() {
    return Padding(
      padding: EdgeInsets.all(12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _cachedMediaPaths.length,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: EdgeInsets.only(
              right: index < _cachedMediaPaths.length - 1 ? 12 : 0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child:
                        _getMediaTypeFromPath(_cachedMediaPaths[index]) ==
                            'image'
                        ? Image.file(
                            File(_cachedMediaPaths[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Symbols.broken_image,
                                          size: 24,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Error',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          )
                        : Container(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.3),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getMediaTypeFromPath(
                                              _cachedMediaPaths[index],
                                            ) ==
                                            'video'
                                        ? Symbols.play_circle
                                        : Symbols.gif,
                                    size: 32,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _getMediaTypeFromPath(
                                              _cachedMediaPaths[index],
                                            ) ==
                                            'video'
                                        ? 'Video'
                                        : 'GIF',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    _getFileNameFromPath(
                                      _cachedMediaPaths[index],
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                // Remove button
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _cachedMediaPaths.removeAt(index);
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(Symbols.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                // File type indicator
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getMediaTypeFromPath(
                        _cachedMediaPaths[index],
                      ).toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getFileNameFromPath(String filePath) {
    return filePath.split('/').last.split('\\').last;
  }

  Widget _buildDevlogMediaViewer(
    List<String> mediaUrls,
    ColorScheme colorScheme,
  ) {
    return _DevlogMediaViewer(mediaUrls: mediaUrls, colorScheme: colorScheme);
  }

  Widget _buildDevlogDescriptionField() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _devlogDescriptionController,
              maxLines: null,
              maxLength: 500,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText:
                    'Share your development progress, challenges, insights, and learnings...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevlogEditorFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _closeDevlogEditor,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            child: Text('Cancel'),
          ),
          SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _handleSaveDevlog,
            icon: Icon(Symbols.save, size: 20),
            label: Text('Publish Devlog'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                'boot@ysws:~/projects/${_project.title.toLowerCase().replaceAll(' ', '_')}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$ cat project.info',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Owner: ${owner.isNotEmpty ? owner : 'Unknown User'}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUploadPic() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final supabasePath = '${_project.id}/picture';
      String supabasePrivateUrl =
          await SupabaseStorageService.uploadFileWithPicker(
            bucket: 'Projects',
            supabasePath: supabasePath,
          );
      if (!mounted) return;
      if (supabasePrivateUrl == 'User cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload picture: $supabasePrivateUrl'),
          ),
        );
        return;
      }

      String? supabasePublicUrl = await SupabaseStorageService.getPublicUrl(
        bucket: 'Projects',
        supabasePath: supabasePrivateUrl,
      );
      if (!mounted) return;

      if (supabasePublicUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get public url for profile picture'),
          ),
        );
        return;
      }
      setState(() {
        _project.imageURL =
            '$supabasePublicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      });
      ProjectService.updateProject(_project);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Picture uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload picture: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProjectImage(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _project.imageURL.isNotEmpty
            ? MouseRegion(
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                cursor: _isOwner()
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: Stack(
                  children: [
                    Image.network(
                      _project.imageURL,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colorScheme.surfaceContainer,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Symbols.broken_image,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              if (_isOwner()) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleUploadPic,
                                  icon: _isLoading
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  colorScheme.onPrimary,
                                                ),
                                          ),
                                        )
                                      : Icon(Symbols.upload, size: 20),
                                  label: Text(
                                    _isLoading
                                        ? 'Uploading...'
                                        : 'Upload Image',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Hover overlay when image is loaded and user is owner
                    if (_isOwner() && _isHovering)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: _isLoading ? null : _handleUploadPic,
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: _isLoading
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Uploading...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Symbols.upload,
                                          size: 48,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Change Image',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Container(
                color: colorScheme.surfaceContainer,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.image,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No image available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_isOwner()) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleUploadPic,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : Icon(Symbols.upload, size: 20),
                          label: Text(
                            _isLoading ? 'Uploading...' : 'Upload Image',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProjectInfo(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _project.title,
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ProjectService.getStatusColor(
                        _project.status,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ProjectService.getStatusColor(_project.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _project.status,
                      style: textTheme.bodyMedium?.copyWith(
                        color: ProjectService.getStatusColor(_project.status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (UserService.currentUser?.id ==
                      '7f18c57b-ca6f-4812-aac7-a2fb6cc10362') ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showStatusEditDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Symbols.edit,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _project.description,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Divider(
            color: colorScheme.outline.withValues(alpha: 0.3),
            thickness: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Symbols.schedule,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tracked development time: ${_project.readableTime}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLiking ? null : _handleLikeProject,
                icon: _isLiked
                    ? Icon(Symbols.favorite, size: 18, fill: 1)
                    : Icon(Symbols.favorite, size: 18, fill: 0),
                label: Text('${_project.likes}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _handleOpenGitHubRepo,
                icon: Icon(Symbols.folder_data, size: 18),
                label: Text('Github Repo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            color: colorScheme.outline.withValues(alpha: 0.3),
            thickness: 1,
          ),
          const SizedBox(height: 8),
          _buildProjectStats(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildProjectStats(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Symbols.calendar_today,
            label: 'Created',
            value: timeAgoSinceDate(_project.createdAt),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Symbols.trending_up,
            label: 'Level',
            value: _project.level,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectImage(colorScheme),
            const SizedBox(height: 24),
            _buildProjectInfo(colorScheme, textTheme),
            if (_isOwner()) ...[
              const SizedBox(height: 16),
              _buildOwnerActions(colorScheme, textTheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerActions(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: colorScheme.outline.withValues(alpha: 0.3),
            thickness: 1,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _project.status.toLowerCase().contains('shipped')
                        ? null
                        : () => _showShipConfirmationDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _project.status.toLowerCase().contains('shipped')
                          ? colorScheme.outline
                          : null,
                      foregroundColor:
                          _project.status.toLowerCase().contains('shipped')
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(Symbols.directions_boat, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _project.status.toLowerCase().contains('shipped')
                              ? 'Already Shipped'
                              : 'Ship Project',
                        ),
                      ],
                    ),
                  ),
                  if (_project.status.toLowerCase().contains('shipped')) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message:
                          'You cannot ship again until your first ship is completed',
                      child: Icon(
                        Symbols.info,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              ElevatedButton(
                onPressed: () {},

                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                child: Text('Delete Project'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDevlogSection(ColorScheme colorScheme, TextTheme textTheme) {
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
                Icon(Symbols.edit_note, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Development Logs',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isOwner())
                  OutlinedButton.icon(
                    onPressed: _handleCreateDevlog,
                    icon: Icon(Symbols.add, size: 18),
                    label: Text('New Entry'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      side: BorderSide(color: colorScheme.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Display devlogs or empty state
            if (_devlogs.isNotEmpty) ...[
              // Display devlogs
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _devlogs.length,
                itemBuilder: (context, index) {
                  final devlog = _devlogs[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
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
                          _buildDevlogMediaViewer(
                            devlog.mediaUrls,
                            colorScheme,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ] else ...[
              // Owner section for empty state
              if (_isOwner()) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Symbols.person,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Share Your Development Journey',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Document your progress, challenges, insights, etc. You must make a devlog every 5 hours of work but it is better to make them more frequently!',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _handleCreateDevlog,
                        icon: Icon(Symbols.edit, size: 20),
                        label: Text('Write Your First Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Empty state
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Symbols.article,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No development logs yet',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOwner()
                          ? 'Start documenting your development process and share your insights'
                          : 'Check back later for development updates and insights from ${owner.isNotEmpty ? owner : 'the project owner'}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                _project.title,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Projects',
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 1,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: Responsive.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTerminalHeader(colorScheme, textTheme),
                SizedBox(height: Responsive.spacing(context)),
                _buildAboutSection(colorScheme, textTheme),
                SizedBox(height: Responsive.spacing(context)),
                _buildDevlogSection(colorScheme, textTheme),
              ],
            ),
          ),
          if (_showDevlogEditor) _buildDevlogEditor(),
        ],
      ),
    );
  }
}

// Separate stateful widget for media viewer
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
