//Packages
import 'dart:io';
import 'package:boot_app/services/hackatime/hackatime_service.dart';
import 'package:boot_app/services/ships/ship_service.dart';
import 'package:boot_app/services/ships/Boot_Ship.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:boot_app/services/users/Boot_User.dart';
import 'package:boot_app/widgets/shared_navigation_rail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
//Theme Data

//Services
import '/services/Projects/Project.dart';
import '/services/Projects/project_service.dart';
import '/services/navigation/navigation_service.dart';
import '../../services/Storage/storage.dart';
import '/services/supabase/DB/functions/supabase_db_functions.dart';
import '../../services/devlog/Devlog.dart';
import '/services/devlog/devlog_service.dart';
import '/theme/responsive.dart';
import '/theme/terminal_theme.dart';
import '/services/notifications/notifications.dart';
import '/services/challenges/Challenge.dart';
import '/services/challenges/Challenge_Service.dart';
import '/services/prizes/Prize.dart';
import '/services/prizes/Prize_Service.dart';
import '/pages/Challenges/Challenge_page.dart';

class ProjectDetailPage extends StatefulWidget {
  final Project project;
  final int? challengeId;

  const ProjectDetailPage({
    super.key,
    required this.project,
    this.challengeId,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  AnimationController? _refreshController;
  late Project _project;
  List<Devlog> _devlogs = [];
  List<Ship> _ships = [];
  bool _isLoading = false;
  bool _isHovering = false;
  BootUser? owner;
  bool _isLiked = false;
  bool _isLiking = false;
  bool _showDevlogEditor = false;
  final TextEditingController _devlogTitleController = TextEditingController();
  final TextEditingController _devlogDescriptionController =
      TextEditingController();
  final List<PlatformFile> _cachedMediaFiles = [];
  bool _isUploadingMedia = false;
  bool _isSubmittingDevlog = false;
  bool _devlogTitleDirty = false;
  bool _devlogDescriptionDirty = false;
  bool _devlogMediaDirty = false;
  bool _devlogValidationAttempted = false;
  bool _isEditMode = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _githubRepoController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  TextEditingController? _currentTagController;
  List<String> _filteredTagSuggestions = [];
  bool _showTagSuggestions = false;
  List<Challenge> _projectChallenges = [];
  List<Challenge> _filteredProjectChallenges = [];
  Map<String, Prize> _prizeCacheForChallenges = {};
  ChallengeType? _selectedChallengeType;
  ChallengeDifficulty? _selectedChallengeDifficulty;
  double _timeToAdd = 0.0;
  String _timeToAddReadable = '0m';
  bool _isFetchingTime = false;
  List<int> _selectedChallengeIds = [];
  int? _preselectedChallengeId;

  final List<String> _popularTags = [
    // Build Type
    'From Scratch',
    'Based On Distro',
    // Operating Systems / Bases
    'Ubuntu',
    'Debian',
    'Fedora',
    'Arch',
    'Alpine',
    'Red Hat',
    'Gentoo',
    // Architectures
    'x86-64',
    'ARM',
    'ARM64',
    'RISC-V',
    'PowerPC',
    // Technologies
    'Linux',
    'Kernel',
    'SystemD',
    'Busybox',
    'Musl',
    'glibc',
    // Features
    'Minimal',
    'Desktop',
    'Server',
    'Embedded',
    'IoT',
    'Container',
    'Virtual Machine',
    // Tools & Utilities
    'Docker',
    'Buildroot',
    'LFS',
    'Yocto',
    'OpenWrt',
    // Languages
    'C',
    'Rust',
    'Shell Script',
    'Python',
  ];

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _titleController.text = _project.title;
    _descriptionController.text = _project.description;
    _githubRepoController.text = _project.githubRepo;
    _tagsController.text = _project.tags.join(', ');
    _loadOwner();
    _loadDevlogs();
    _loadShips();
    _loadProjectChallenges();
    _refreshController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _userLiked();

    // Check if opened with challengeId to auto-open devlog editor
    if (widget.challengeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isOwner()) {
          _handleCreateDevlog(challengeId: widget.challengeId);
        }
      });
    }
  }

  Future<void> _loadOwner() async {
    final user = await UserService.getUserById(_project.owner);
    setState(() {
      owner = user;
    });
  }

  Future<void> _loadDevlogs() async {
    try {
      final devlogs = await DevlogService.getDevlogsByProjectId(
        _project.id.toString(),
      );
      setState(() {
        _devlogs = devlogs.reversed.toList();
      });
    } catch (e) {
      // Error loading devlogs: $e
    }
  }

  Future<void> _loadShips() async {
    try {
      final ships = await ShipService.getShipsByProject(
        _project.id.toString(),
      );
      ships.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _ships = ships;
      });
    } catch (e) {
      // Error loading ships: $e
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

  Future<void> _loadProjectChallenges() async {
    try {
      final allChallenges = await ChallengeService.fetchChallenges();

      // Filter challenges based on project type
      List<Challenge> relevantChallenges = allChallenges.where((challenge) {
        // If project is from scratch, exclude base challenges
        if (_project.level.toLowerCase().contains('scratch')) {
          return challenge.type != ChallengeType.base;
        }
        // If project is base, exclude scratch challenges
        else if (_project.level.toLowerCase().contains('base')) {
          return challenge.type != ChallengeType.scratch;
        }
        // Otherwise show all challenges
        return true;
      }).toList();

      // Load prizes for challenges
      final prizeIds = relevantChallenges
          .map((c) => c.prize)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (prizeIds.isNotEmpty) {
        final prizes = await PrizeService.getPrizesByIds(prizeIds);
        _prizeCacheForChallenges = {for (var prize in prizes) prize.id: prize};
      }

      if (mounted) {
        setState(() {
          _projectChallenges = relevantChallenges;
          _applyProjectChallengeFilters();
        });
      }
    } catch (e) {
      // Error loading challenges
    }
  }

  void _applyProjectChallengeFilters() {
    List<Challenge> filtered = List.from(_projectChallenges);

    // Filter out expired and inactive challenges
    filtered = filtered.where((challenge) {
      final isExpired = challenge.endDate.isBefore(DateTime.now());
      return challenge.isActive && !isExpired;
    }).toList();

    // Apply type filter
    if (_selectedChallengeType != null) {
      filtered = filtered
          .where((c) => c.type == _selectedChallengeType)
          .toList();
    }

    // Apply difficulty filter
    if (_selectedChallengeDifficulty != null) {
      filtered = filtered
          .where((c) => c.difficulty == _selectedChallengeDifficulty)
          .toList();
    }

    setState(() {
      _filteredProjectChallenges = filtered;
    });
  }

  @override
  void dispose() {
    _refreshController?.dispose();
    _devlogTitleController.dispose();
    _devlogDescriptionController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _githubRepoController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  DateTime _ensureUtc(DateTime date) => date.isUtc ? date : date.toUtc();

  String timeAgoSinceDate(DateTime date) {
    final now = DateTime.now().toUtc();
    final utcDate = date.isUtc ? date : date.toUtc();
    final difference = now.difference(utcDate);
    if (difference.isNegative) return 'just now';
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
    if (_project.owner == UserService.currentUser?.id) {
      if (!mounted) return;
      GlobalNotificationService.instance.showWarning(
        "You can't like your own OS.\nSilly Goose",
      );
      return;
    }
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
        GlobalNotificationService.instance.showInfo(
          'You unliked ${_project.title}.',
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
        GlobalNotificationService.instance.showSuccess(
          'You liked ${_project.title}!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to like/unlike project: $e',
      );
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

  /*Future<void> _handleTestOS() async {
    try {
      await TestingManager.openBootHelper(_project, context);
    } catch (e) {
      // Error is already handled in TestingManager
    }
  }*/

  Future<void> _handleCreateDevlog({int? challengeId}) async {
    setState(() {
      _showDevlogEditor = true;
      _devlogValidationAttempted = false;
      _devlogTitleDirty = false;
      _devlogDescriptionDirty = false;
      _devlogMediaDirty = false;
      _isFetchingTime = true;
      _selectedChallengeIds = [];
      _preselectedChallengeId = challengeId;
      if (challengeId != null && !_project.challengeIds.contains(challengeId)) {
        _selectedChallengeIds.add(challengeId);
      }
    });

    // Fetch current time to calculate difference
    try {
      final updatedProject = await HackatimeService.getProjectTime(
        project: _project,
        slackUserId: UserService.currentUser?.slackUserId ?? '',
        context: context,
      );

      _project = await ProjectService.getProjectById(_project.id) ?? _project;

      final timeDiff = updatedProject.time - _project.time;
      
      if (mounted) {
        setState(() {
          _timeToAdd = timeDiff;
          _timeToAddReadable = _formatReadableDuration((timeDiff * 3600).round());
          _isFetchingTime = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingTime = false;
          _timeToAdd = 0;
          _timeToAddReadable = 'Error';
        });
      }
    }
  }

  void _closeDevlogEditor() {
    setState(() {
      _showDevlogEditor = false;
      _devlogTitleController.clear();
      _devlogDescriptionController.clear();
      _cachedMediaFiles.clear();
      _devlogValidationAttempted = false;
      _devlogTitleDirty = false;
      _devlogDescriptionDirty = false;
      _devlogMediaDirty = false;
      _timeToAdd = 0.0;
      _timeToAddReadable = '0m';
      _selectedChallengeIds = [];
      _preselectedChallengeId = null;
    });
  }

  Future<void> _handleUploadDevlogMedia() async {
    setState(() {
      _isUploadingMedia = true;
      _devlogMediaDirty = true;
    });

    try {
      final cachedFile = await DevlogService.cacheMediaFilePicker();
      if (cachedFile != null) {
        setState(() {
          _cachedMediaFiles.add(cachedFile);
          _devlogMediaDirty = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError('Failed to cache media: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }

  Future<void> _handleSaveDevlog() async {
    if (_isSubmittingDevlog) return;

    setState(() {
      _devlogValidationAttempted = true;
      _devlogTitleDirty = true;
      _devlogDescriptionDirty = true;
      _devlogMediaDirty = true;
    });

    if (!_validateDevlogForm()) {
      return;
    }

    // Validate that work was done (minimum 5 minutes)
    if (_timeToAdd <= 0) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'You cannot publish a devlog without working on the project. What do you need to talk about if you did nothing?',
      );
      return;
    }
    
    // Validate minimum 5 minutes of work
    final timeInMinutes = (_timeToAdd * 60).round();
    if (timeInMinutes < 5) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'You must work at least 5 minutes before publishing a devlog. Current time: ${timeInMinutes}m',
      );
      return;
    }

    setState(() => _isSubmittingDevlog = true);

    try {
      final updatedProject = await HackatimeService.getProjectTime(
        project: _project,
        slackUserId: UserService.currentUser?.slackUserId ?? '',
        context: context,
      );

      await DevlogService.addDevlog(
        projectID: _project.id,
        title: _devlogTitleController.text,
        description: _devlogDescriptionController.text,
        cachedMediaFiles: _cachedMediaFiles,
        readableTime: updatedProject.readableTime,
        time: updatedProject.time,
        challengeIds: _selectedChallengeIds,
      );

      // Mark challenges as completed on the project
      if (_selectedChallengeIds.isNotEmpty) {
        final updatedChallengeIds = List<int>.from(_project.challengeIds);
        for (final challengeId in _selectedChallengeIds) {
          if (!updatedChallengeIds.contains(challengeId)) {
            updatedChallengeIds.add(challengeId);
          }
        }
        _project.challengeIds = updatedChallengeIds;
        await ProjectService.updateProject(_project);
      }

      // Refresh devlogs to include new entry with media URLs
      await _loadDevlogs();
      await _loadProjectChallenges();
      setState(() {
        _project.time = updatedProject.time;
        _project.readableTime = updatedProject.readableTime;
        _isSubmittingDevlog = false;
      });
      _closeDevlogEditor();
    } catch (e) {
      setState(() => _isSubmittingDevlog = false);
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to publish devlog: $e',
      );
    }
  }

  bool _isOwner() {
    return UserService.currentUser?.id == _project.owner;
  }

  String _formatReadableDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }

  String? get _devlogTitleError {
    final text = _devlogTitleController.text.trim();
    if (text.isEmpty) return 'Title is required';
    if (text.length <= 2) return 'Title must be at least 3 characters';
    return null;
  }

  String? get _devlogDescriptionError {
    final text = _devlogDescriptionController.text.trim();
    if (text.isEmpty) return 'Description is required';
    if (text.length <= 150) {
      return 'Description must be more than 150 characters';
    }
    return null;
  }

  String? get _devlogMediaError {
    if (_cachedMediaFiles.isEmpty) {
      return 'Add at least one media file to your devlog';
    }
    return null;
  }

  bool get _showDevlogTitleError =>
      _devlogTitleDirty || _devlogValidationAttempted;

  bool get _showDevlogDescriptionError =>
      _devlogDescriptionDirty || _devlogValidationAttempted;

  bool get _showDevlogMediaError =>
      _devlogMediaDirty || _devlogValidationAttempted;

  bool _validateDevlogForm() {
    final titleError = _devlogTitleError;
    final descriptionError = _devlogDescriptionError;
    final mediaError = _devlogMediaError;

    if (titleError != null) {
      GlobalNotificationService.instance.showError(titleError);
      return false;
    }
    if (descriptionError != null) {
      GlobalNotificationService.instance.showError(descriptionError);
      return false;
    }
    if (mediaError != null) {
      GlobalNotificationService.instance.showError(mediaError);
      return false;
    }
    return true;
  }

  Future<void> _showTestOSDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.computer,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Test Your OS',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Symbols.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'To test your operating system, you\'ll need to set up a virtual machine on your own computer.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Symbols.lightbulb,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Here\'s how:',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTestStep(
                        '1.',
                        'Download the ISO from your GitHub repository',
                        colorScheme,
                        textTheme,
                      ),
                      const SizedBox(height: 8),
                      _buildTestStep(
                        '2.',
                        'Set up a virtual machine using software like VirtualBox or VMware',
                        colorScheme,
                        textTheme,
                      ),
                      const SizedBox(height: 8),
                      _buildTestStep(
                        '3.',
                        'Boot the ISO in your VM to test your OS',
                        colorScheme,
                        textTheme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Not sure how to get started? We have a comprehensive guide to help you through the process.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to guide or open guide URL
                        Navigator.of(context).pop();
                        GlobalNotificationService.instance.showInfo(
                          'Guide coming soon!',
                        );
                      },
                      icon: Icon(Symbols.book, size: 20),
                      label: Text('Go to Guide'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestStep(
    String number,
    String text,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
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
                  'Ready for review',
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
                    'Once shipped, your project will be submitted for review.',
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
      _project = await ProjectService.getProjectById(_project.id) ?? _project;
      final newShip = await ShipService.addShip(
        project: _project.id,
        time: _project.time,
        challengesRequested: _project.challengeIds,
      );

      setState(() {
        _ships.insert(0, newShip);
        _project.status = 'Shipped / Awaiting Review';
      });

      _showShipSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to ship project: $e',
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
                      'Your project is now being reviewed. You will be notified once the review is complete.',
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

  String _getMediaType(PlatformFile file) {
    final extension = file.extension?.toLowerCase() ?? '';
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return 'image';
      case 'mp4':
        return 'video';
      case 'gif':
        return 'gif';
      default:
        return 'unknown';
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDevlogMediaSection(),
                      SizedBox(height: 24),
                      _buildDevlogTitleField(),
                      SizedBox(height: 24),
                      _buildDevlogDescriptionField(),
                      SizedBox(height: 24),
                      _buildChallengeSelector(),
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
          onChanged: (_) => setState(() => _devlogTitleDirty = true),
          decoration: InputDecoration(
            hintText: 'Enter devlog title...',
            helperText: _showDevlogTitleError && _devlogTitleError != null
                ? null
                : 'Minimum 3 characters',
            errorText: _showDevlogTitleError ? _devlogTitleError : null,
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
            if (_cachedMediaFiles.isNotEmpty)
              Text(
                '${_cachedMediaFiles.length} file${_cachedMediaFiles.length == 1 ? '' : 's'}',
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
          child: _cachedMediaFiles.isEmpty
              ? _buildMediaUploadArea()
              : _buildMediaCarousel(),
        ),
        if (_showDevlogMediaError && _cachedMediaFiles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Symbols.error,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _devlogMediaError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_cachedMediaFiles.isNotEmpty) ...[
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
                    _cachedMediaFiles.clear();
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
        itemCount: _cachedMediaFiles.length,
        itemBuilder: (context, index) {
          final file = _cachedMediaFiles[index];
          return Container(
            width: 160,
            margin: EdgeInsets.only(
              right: index < _cachedMediaFiles.length - 1 ? 12 : 0,
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
                        _getMediaType(file) == 'image' ||
                            _getMediaType(file) == 'gif'
                        ? (kIsWeb
                              ? Image.memory(
                                  file.bytes!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPreviewError(),
                                )
                              : Image.file(
                                  File(file.path!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPreviewError(),
                                ))
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
                                    _getMediaType(file) == 'video'
                                        ? Symbols.play_circle
                                        : Symbols.error, // Fallback icon
                                    size: 32,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _getMediaType(file) == 'video'
                                        ? 'Video'
                                        : 'Unsupported',
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
                                    file.name,
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
                          _cachedMediaFiles.removeAt(index);
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
                      _getMediaType(file).toUpperCase(),
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

  Widget _buildPreviewError() {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.broken_image,
              size: 24,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: 4),
            Text(
              'Error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
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

  Widget _buildDevlogDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Markdown supported',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: TextField(
            controller: _devlogDescriptionController,
            maxLines: null,
            maxLength: 2000,
            expands: true,
            onChanged: (_) => setState(() => _devlogDescriptionDirty = true),
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText:
                  'Share your development progress, challenges, insights, and learnings...',
              helperText:
                  _showDevlogDescriptionError &&
                          _devlogDescriptionError != null
                      ? null
                      : 'Must be more than 150 characters',
              errorText:
                  _showDevlogDescriptionError ? _devlogDescriptionError : null,
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
    );
  }

  Widget _buildChallengeSelector() {
    final availableChallenges = _projectChallenges
        .where((c) => !_project.challengeIds.contains(c.id))
        .toList();

    if (availableChallenges.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Symbols.flag,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Text(
              'Challenges Completed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          'Select challenges you completed in this devlog',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableChallenges.map((challenge) {
            final isSelected = _selectedChallengeIds.contains(challenge.id);
            return FilterChip(
              label: Text(challenge.title),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedChallengeIds.add(challenge.id);
                  } else {
                    _selectedChallengeIds.remove(challenge.id);
                  }
                });
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.primary,
            );
          }).toList(),
        ),
      ],
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time tracking display
          if (_isFetchingTime)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Calculating time...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _timeToAdd > 0
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _timeToAdd > 0
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.schedule,
                    size: 18,
                    color: _timeToAdd > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _timeToAdd > 0
                        ? 'Time to add: $_timeToAddReadable'
                        : 'No work detected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _timeToAdd > 0
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Row(
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
                onPressed: _isSubmittingDevlog ? null : _handleSaveDevlog,
                icon: _isSubmittingDevlog
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(Symbols.save, size: 20),
                label: Text(_isSubmittingDevlog ? 'Publishing...' : 'Publish Devlog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
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
            'Owner: ${owner?.username ?? 'Unknown User'}',
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
      final supabasePath = 'projects/${_project.id}/picture';
      String supabasePrivateUrl = await StorageService.uploadFileWithPicker(
        path: supabasePath,
      );
      if (!mounted) return;
      if (supabasePrivateUrl == 'User cancelled') {
        GlobalNotificationService.instance.showWarning('Upload cancelled');
        return;
      }

      String? supabasePublicUrl = await StorageService.getPublicUrl(
        path: supabasePrivateUrl,
      );
      if (!mounted) return;

      if (supabasePublicUrl == null) {
        GlobalNotificationService.instance.showError(
          'Failed to get public url for profile picture',
        );
        return;
      }
      setState(() {
        _project.imageURL =
            '$supabasePublicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      });
      ProjectService.updateProject(_project);
      if (!mounted) return;

      GlobalNotificationService.instance.showSuccess(
        'Picture uploaded successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to upload picture: $e',
      );
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
                child: _isEditMode
                    ? TextField(
                        controller: _titleController,
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Project Title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _project.title,
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              if (_isOwner() && !_isEditMode)
                PopupMenuButton<String>(
                  icon: Icon(Symbols.more_vert, color: colorScheme.onSurface),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Symbols.edit, size: 20),
                          const SizedBox(width: 8),
                          Text('Edit Project'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Symbols.delete,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete Project',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      setState(() => _isEditMode = true);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created by',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (owner != null) {
                          NavigationService.openProfile(owner!, context);
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: owner != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (owner!.profilePicture.isNotEmpty)
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage(
                                      owner!.profilePicture,
                                    ),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 16,
                                    child: Icon(
                                      Symbols.person,
                                      size: 14,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  owner!.username,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Unknown',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_isEditMode)
                Text(
                  'Markdown supported',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _isEditMode
              ? TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Project Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                )
              : MarkdownBody(
                  data: _project.description,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                    h1: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    h2: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    h3: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    code: TextStyle(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      color: colorScheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                    blockquote: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    a: TextStyle(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
          const SizedBox(height: 32),
          if (_project.tags.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Symbols.label,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _project.tags
                        .map((tag) => Chip(
                          label: Text(tag),
                          onDeleted: _isEditMode
                              ? () {
                                  setState(() {
                                    _project.tags.remove(tag);
                                  });
                                }
                              : null,
                        ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          if (_isEditMode) ...[
            Row(
              children: [
                Icon(
                  Symbols.link,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _githubRepoController,
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'GitHub Repository URL',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tags',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _popularTags.where((tag) => !_project.tags.contains(tag)).toList();
                }
                final input = textEditingValue.text.toLowerCase();
                return _popularTags.where((tag) => 
                  tag.toLowerCase().contains(input) && 
                  !_project.tags.contains(tag)
                ).toList();
              },
              onSelected: (String selection) {
                setState(() {
                  if (!_project.tags.contains(selection)) {
                    _project.tags.add(selection);
                  }
                });
                _currentTagController?.clear();
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _currentTagController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Add a tag',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onSubmitted: (value) {
                    final tag = value.trim();
                    if (tag.isNotEmpty && !_project.tags.contains(tag)) {
                      setState(() => _project.tags.add(tag));
                    }
                    _currentTagController?.clear();
                    onFieldSubmitted();
                  },
                );
              },
            ),
            if (_project.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _project.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() => _project.tags.remove(tag));
                    },
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditMode = false;
                      _titleController.text = _project.title;
                      _descriptionController.text = _project.description;
                      _githubRepoController.text = _project.githubRepo;
                      _tagsController.text = _project.tags.join(', ');
                    });
                  },
                  child: Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _handleSaveProject,
                  icon: Icon(Symbols.save, size: 20),
                  label: Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: colorScheme.outline.withValues(alpha: 0.3),
          thickness: 1,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - ship button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.directions_boat, size: 20),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Symbols.info,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'You cannot ship again until your first ship is completed',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _showTestOSDialog(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.primary),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.play_circle, size: 20),
                        const SizedBox(width: 8),
                        Text('Test OS'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right side - challenges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledFilter(
                          icon: Symbols.category,
                          label: _selectedChallengeType == null
                              ? 'Type'
                              : _selectedChallengeType
                                    .toString()
                                    .split('.')
                                    .last,
                          isActive: _selectedChallengeType != null,
                          items: [
                            _FilterItem(
                              label: 'All Types',
                              value: null,
                              onTap: () {
                                setState(() {
                                  _selectedChallengeType = null;
                                  _applyProjectChallengeFilters();
                                });
                              },
                            ),
                            ...ChallengeType.values.map(
                              (type) => _FilterItem(
                                label: type
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                value: type,
                                onTap: () {
                                  setState(() {
                                    _selectedChallengeType = type;
                                    _applyProjectChallengeFilters();
                                  });
                                },
                              ),
                            ),
                          ],
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledFilter(
                          icon: Symbols.signal_cellular_alt,
                          label: _selectedChallengeDifficulty == null
                              ? 'Difficulty'
                              : _selectedChallengeDifficulty
                                    .toString()
                                    .split('.')
                                    .last,
                          isActive: _selectedChallengeDifficulty != null,
                          items: [
                            _FilterItem(
                              label: 'All Levels',
                              value: null,
                              onTap: () {
                                setState(() {
                                  _selectedChallengeDifficulty = null;
                                  _applyProjectChallengeFilters();
                                });
                              },
                            ),
                            ...ChallengeDifficulty.values.map(
                              (difficulty) => _FilterItem(
                                label: difficulty
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                value: difficulty,
                                onTap: () {
                                  setState(() {
                                    _selectedChallengeDifficulty = difficulty;
                                    _applyProjectChallengeFilters();
                                  });
                                },
                              ),
                            ),
                          ],
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Symbols.mountain_flag,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Available Challenges',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_filteredProjectChallenges.isEmpty)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Symbols.search_off,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No challenges found',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ListView.separated(
                        itemCount: _filteredProjectChallenges.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                        itemBuilder: (context, index) {
                          final challenge = _filteredProjectChallenges[index];
                          return _buildCompactChallengeCard(
                            challenge,
                            colorScheme,
                            textTheme,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyledFilter({
    required IconData icon,
    required String label,
    required bool isActive,
    required List<_FilterItem> items,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return PopupMenuButton<dynamic>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: TerminalColors.green, width: 2),
      ),
      color: colorScheme.surface,
      elevation: 8,
      offset: const Offset(0, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    TerminalColors.green.withValues(alpha: 0.2),
                    TerminalColors.green.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? TerminalColors.green
                : colorScheme.outline.withValues(alpha: 0.4),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: TerminalColors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? TerminalColors.green
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: isActive
                      ? TerminalColors.green
                      : colorScheme.onSurface,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Icon(
              Symbols.arrow_drop_down,
              size: 18,
              color: isActive
                  ? TerminalColors.green
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => items.map((item) {
        final bool isSelected =
            item.value ==
            (icon == Symbols.category
                ? _selectedChallengeType
                : _selectedChallengeDifficulty);
        return PopupMenuItem(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: item.onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? TerminalColors.green.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? TerminalColors.green
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (isSelected) ...[
                    Icon(Symbols.check, size: 18, color: TerminalColors.green),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? TerminalColors.green
                            : colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleSaveProject() async {
    try {
      setState(() {
        _project.title = _titleController.text;
        _project.description = _descriptionController.text;
        _project.githubRepo = _githubRepoController.text;
        _isEditMode = false;
      });

      await ProjectService.updateProject(_project);

      if (!mounted) return;
      GlobalNotificationService.instance.showSuccess(
        'Project updated successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to update project: $e',
      );
    }
  }

  Future<void> _showDeleteConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Symbols.warning, color: colorScheme.error),
              const SizedBox(width: 8),
              Text('Delete Project?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${_project.title}"?',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone. All project data, devlogs, and associated information will be permanently deleted.',
                style: textTheme.bodyMedium,
              ),
            ],
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
                _showFinalDeleteConfirmation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFinalDeleteConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Symbols.warning, color: colorScheme.error),
              const SizedBox(width: 8),
              Text('Final Confirmation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you ABSOLUTELY sure?',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "I am not joking everything will be deleted. Like it never happened. (This won't delete your GitHub repo)",
                style: textTheme.bodyMedium,
              ),
            ],
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
                _handleDeleteProject();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: Text('Delete Anyway'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDeleteProject() async {
    try {
      await ProjectService.deleteProject(
        projectId: _project.id,
        ownerId: _project.owner,
      );

      if (!mounted) return;
      GlobalNotificationService.instance.showSuccess(
        'Project deleted successfully',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to delete project: $e',
      );
    }
  }

  List<_TimelineEntry> _buildTimelineEntries() {
    final entries = <_TimelineEntry>[];

    entries.add(
      _TimelineEntry(
        date: _project.createdAt,
        sortDate: _ensureUtc(_project.createdAt),
        title: 'Project created',
        subtitle: _formatTimelineDate(_project.createdAt),
        icon: Symbols.flag,
        color: TerminalColors.green,
      ),
    );

    if (_project.lastModified.isAfter(
      _project.createdAt.add(const Duration(minutes: 1)),
    )) {
      entries.add(
        _TimelineEntry(
          date: _project.lastModified,
          sortDate: _ensureUtc(_project.lastModified),
          title: 'Project updated',
          subtitle: _formatTimelineDate(_project.lastModified),
          icon: Symbols.edit,
          color: TerminalColors.cyan,
        ),
      );
    }

    for (final ship in _ships) {
      // Ship submission entry
      entries.add(
        _TimelineEntry(
          date: ship.createdAt,
          sortDate: _ensureUtc(ship.createdAt),
          title: 'Ship submitted',
          subtitle: '${_formatTimelineDate(ship.createdAt)} · ${ship.time.toStringAsFixed(1)}h tracked',
          icon: Symbols.directions_boat,
          color: TerminalColors.yellow,
        ),
      );

      // Ship review entry (if reviewed)
      if (ship.reviewed) {
        entries.add(
          _TimelineEntry(
            date: ship.createdAt,
            sortDate: _ensureUtc(ship.createdAt).add(const Duration(minutes: 1)), // small offset for ordering without affecting display
            title: ship.approved ? 'Ship approved ✓' : 'Ship reviewed',
            subtitle: _formatTimelineDate(ship.createdAt),
            icon: ship.approved ? Symbols.check_circle : Symbols.rate_review,
            color: TerminalColors.yellow,
            body: FutureBuilder<BootUser?>(
              future: ship.reviewer.isNotEmpty 
                  ? UserService.getUserById(ship.reviewer)
                  : Future.value(null),
              builder: (context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.hasData && snapshot.data != null) ...[
                      Row(
                        children: [
                          Icon(
                            Symbols.person,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Reviewed by: ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          InkWell(
                            onTap: () {
                              NavigationService.openProfile(snapshot.data!, context);
                            },
                            child: Text(
                              snapshot.data!.username,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (ship.comment.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          ship.comment,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      }
    }

    for (final devlog in _devlogs) {
      entries.add(
        _TimelineEntry(
          date: devlog.createdAt,
          sortDate: _ensureUtc(devlog.createdAt),
          title: devlog.title,
          subtitle: _formatTimelineDate(devlog.createdAt),
          icon: Symbols.edit_note,
          color: TerminalColors.blue,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (devlog.timeReadable.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Symbols.schedule,
                      size: 14,
                      color: TerminalColors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Time tracked: ${devlog.timeReadable}',
                      style: TextStyle(
                        color: TerminalColors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (devlog.challenges.isNotEmpty) ...[
                FutureBuilder<List<Challenge>>(
                  future: Future.wait(
                    devlog.challenges.map(
                      (id) => ChallengeService.getChallengeById(id),
                    ),
                  ).then((challenges) => challenges.whereType<Challenge>().toList()),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Symbols.flag,
                                size: 14,
                                color: TerminalColors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Challenges completed:',
                                style: TextStyle(
                                  color: TerminalColors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: snapshot.data!.map((challenge) {
                              return Chip(
                                label: Text(
                                  challenge.title,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                avatar: Icon(
                                  Symbols.check_circle,
                                  size: 16,
                                  color: TerminalColors.green,
                                ),
                                backgroundColor: TerminalColors.green.withValues(alpha: 0.1),
                                side: BorderSide(
                                  color: TerminalColors.green.withValues(alpha: 0.3),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],
              MarkdownBody(
                data: devlog.description,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.5,
                      ) ??
                      const TextStyle(),
                  h1: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  h3: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                  code: TextStyle(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'monospace',
                  ),
                  blockquote: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  a: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (devlog.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDevlogMediaViewer(
                  devlog.mediaUrls,
                  Theme.of(context).colorScheme,
                ),
              ],
            ],
          ),
        ),
      );
    }

    entries.sort((a, b) => b.sortDate.toUtc().compareTo(a.sortDate.toUtc()));
    return entries;
  }

  Widget _buildTimelineTile(
    _TimelineEntry entry,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isLast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: entry.color ?? colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                entry.icon,
                size: 10,
                color: colorScheme.onPrimary,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: colorScheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: entry.color ?? colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      timeAgoSinceDate(entry.date),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (entry.body != null) ...[
                  const SizedBox(height: 10),
                  entry.body!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimelineDate(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateFormat('MMM d, yyyy • h:mm a').format(localDate);
  }

  Widget _buildDevlogSection(ColorScheme colorScheme, TextTheme textTheme) {
    final timelineEntries = _buildTimelineEntries();
    final hasDevlogsOrShips = _devlogs.isNotEmpty || _ships.isNotEmpty;

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
                Icon(Symbols.timeline, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Timeline',
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

            if (timelineEntries.isNotEmpty) ...[
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: timelineEntries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final entry = timelineEntries[index];
                  final isLast = index == timelineEntries.length - 1;
                  return _buildTimelineTile(
                    entry,
                    colorScheme,
                    textTheme,
                    isLast,
                  );
                },
              ),
            ],

            if (!hasDevlogsOrShips) ...[
              if (_isOwner()) ...[
                const SizedBox(height: 20),
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
              ],

              const SizedBox(height: 20),
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
                          : 'Check back later for development updates and insights from ${owner?.username ?? 'the project owner'}',
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

    return SharedNavigationRail(
      showAppBar: false,
      child: Scaffold(
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
          automaticallyImplyLeading: false,
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
      ),
    );
  }

  Widget _buildCompactChallengeCard(
    Challenge challenge,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final difficultyColor = _getChallengeDifficultyColor(challenge.difficulty);
    final typeIcon = _getChallengeTypeIcon(challenge.type);
    final daysRemaining = challenge.endDate.difference(DateTime.now()).inDays;
    final isExpired = daysRemaining < 0;
    final prize = _prizeCacheForChallenges[challenge.prize];

    return InkWell(
      onTap: () =>
          _showChallengeDetailDialog(challenge, colorScheme, textTheme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Type icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(typeIcon, color: colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            // Challenge info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          challenge.title,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (challenge.isActive && !isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TerminalColors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: TerminalColors.green,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: textTheme.labelSmall?.copyWith(
                              color: TerminalColors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        )
                      else if (isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TerminalColors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: TerminalColors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'EXPIRED',
                            style: textTheme.labelSmall?.copyWith(
                              color: TerminalColors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Type label
                      _buildChallengeTypeLabel(
                        challenge.type,
                        colorScheme,
                        textTheme,
                      ),
                      if (_buildChallengeTypeLabel(
                            challenge.type,
                            colorScheme,
                            textTheme,
                          )
                          is! SizedBox)
                        const SizedBox(width: 8),
                      // Difficulty
                      Icon(
                        Symbols.signal_cellular_alt,
                        size: 12,
                        color: difficultyColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        challenge.difficulty
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        style: textTheme.bodySmall?.copyWith(
                          color: difficultyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Days remaining
                      Icon(
                        Symbols.schedule,
                        size: 12,
                        color: isExpired
                            ? TerminalColors.red
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired
                            ? 'Ended'
                            : '$daysRemaining day${daysRemaining != 1 ? 's' : ''}',
                        style: textTheme.bodySmall?.copyWith(
                          color: isExpired
                              ? TerminalColors.red
                              : colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      // Prize info
                      if (prize != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.featured_seasonal_and_gifts,
                              size: 14,
                              color: TerminalColors.yellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              prize.title,
                              style: textTheme.bodySmall?.copyWith(
                                color: TerminalColors.yellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Symbols.chevron_right,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeTypeLabel(
    ChallengeType type,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    String? label;
    switch (type) {
      case ChallengeType.special:
        label = 'SPECIAL';
        break;
      case ChallengeType.weekly:
        label = 'WEEKLY';
        break;
      case ChallengeType.monthly:
        label = 'MONTHLY';
        break;
      case ChallengeType.scratch:
        label = 'SCRATCH';
        break;
      case ChallengeType.base:
        label = 'BASE';
        break;
      case ChallengeType.normal:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _getChallengeDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return TerminalColors.green;
      case ChallengeDifficulty.medium:
        return TerminalColors.yellow;
      case ChallengeDifficulty.hard:
        return TerminalColors.red;
    }
  }

  IconData _getChallengeTypeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.special:
        return Symbols.star_rate;
      case ChallengeType.weekly:
        return Symbols.date_range;
      case ChallengeType.monthly:
        return Symbols.calendar_month;
      case ChallengeType.scratch:
        return Symbols.code;
      case ChallengeType.base:
        return Symbols.foundation;
      case ChallengeType.normal:
        return Symbols.flag;
    }
  }

  void _showChallengeDetailDialog(
    Challenge challenge,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) async {
    // Get prize from cache or load it
    Prize? prize = _prizeCacheForChallenges[challenge.prize];
    if (prize == null && challenge.prize.isNotEmpty) {
      prize = await PrizeService.getPrizeById(challenge.prize);
      if (prize != null) {
        _prizeCacheForChallenges[challenge.prize] = prize;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ChallengeDetailDialog(
        challenge: challenge,
        prize: prize,
        colorScheme: colorScheme,
        textTheme: textTheme,
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

class _FilterItem {
  final String label;
  final dynamic value;
  final VoidCallback onTap;

  _FilterItem({required this.label, required this.value, required this.onTap});
}

class _TimelineEntry {
  final DateTime date;
  final DateTime sortDate;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final Widget? body;

  _TimelineEntry({
    required this.date,
    DateTime? sortDate,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
    this.body,
  }) : sortDate = sortDate ?? date;
}
