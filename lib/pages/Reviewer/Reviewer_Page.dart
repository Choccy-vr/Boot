import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:boot_app/services/ships/ship_service.dart';
import 'package:boot_app/services/ships/Boot_Ship.dart';
import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/project_service.dart';
import 'package:boot_app/services/challenges/Challenge.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:boot_app/services/notifications/notifications.dart';
import 'package:boot_app/services/Storage/storage.dart';
import 'package:boot_app/pages/Projects/Project_Page.dart'
    deferred as project_page;
import 'package:boot_app/theme/responsive.dart';
import 'package:boot_app/widgets/shared_navigation_rail.dart';
import 'package:boot_app/widgets/deferred_page.dart';

class ReviewerPage extends StatefulWidget {
  const ReviewerPage({super.key});

  @override
  State<ReviewerPage> createState() => _ReviewerPageState();
}

class _ReviewerPageState extends State<ReviewerPage> {
  List<Ship> _unreviewedShips = [];
  Map<int, Project> _projectCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnreviewedShips();
  }

  Future<void> _loadUnreviewedShips() async {
    setState(() => _isLoading = true);
    try {
      final ships = await ShipService.getAllUnreviewedShips();

      // Load projects for all ships
      final projectIds = ships.map((ship) => ship.project).toSet().toList();
      for (final projectId in projectIds) {
        final project = await ProjectService.getProjectById(projectId);
        if (project != null) {
          _projectCache[projectId] = project;
        }
      }

      setState(() {
        _unreviewedShips = ships;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      GlobalNotificationService.instance.showError('Failed to load ships: $e');
    }
  }

  void _navigateToProjectReview(Ship ship, Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectReviewWrapper(
          project: project,
          ship: ship,
          onReviewComplete: () {
            _loadUnreviewedShips();
          },
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.rate_review, color: colorScheme.primary),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Ships to Review',
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
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : _unreviewedShips.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.check_circle,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ships to review',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All ships have been reviewed!',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadUnreviewedShips,
                child: ListView.builder(
                  padding: Responsive.pagePadding(context),
                  itemCount: _unreviewedShips.length,
                  itemBuilder: (context, index) {
                    final ship = _unreviewedShips[index];
                    final project = _projectCache[ship.project];

                    if (project == null) {
                      return const SizedBox.shrink();
                    }

                    return _buildShipCard(
                      ship,
                      project,
                      colorScheme,
                      textTheme,
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildShipCard(
    Ship ship,
    Project project,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToProjectReview(ship, project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Symbols.directions_boat,
                      color: colorScheme.primary,
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
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Shipped ${_timeAgo(ship.createdAt)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Symbols.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                color: colorScheme.outline.withValues(alpha: 0.3),
                height: 1,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Symbols.schedule,
                    label: 'Time: ${project.readableTime}',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(width: 12),
                  if (ship.challengesRequested.isNotEmpty)
                    _buildInfoChip(
                      icon: Symbols.emoji_events,
                      label:
                          '${ship.challengesRequested.length} ${ship.challengesRequested.length == 1 ? 'bounty' : 'bounties'}',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                ],
              ),
              if (ship.challengesRequested.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ship.challengesRequested.map((challenge) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: colorScheme.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        challenge.title,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now().toUtc();
    final utcDate = date.isUtc ? date : date.toUtc();
    final difference = now.difference(utcDate);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30)
      return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays < 365)
      return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  }
}

class ProjectReviewWrapper extends StatefulWidget {
  final Project project;
  final Ship ship;
  final VoidCallback onReviewComplete;

  const ProjectReviewWrapper({
    super.key,
    required this.project,
    required this.ship,
    required this.onReviewComplete,
  });

  @override
  State<ProjectReviewWrapper> createState() => _ProjectReviewWrapperState();
}

class _ProjectReviewWrapperState extends State<ProjectReviewWrapper> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DeferredPage(
        loadLibrary: project_page.loadLibrary,
        buildPage: (_) =>
            project_page.ProjectDetailPage(project: widget.project),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Done reviewing this project?',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showReviewDialog(context),
                icon: const Icon(Symbols.rate_review, size: 20),
                label: const Text('Review'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReviewDialog(
        ship: widget.ship,
        project: widget.project,
        onReviewComplete: () {
          widget.onReviewComplete();
          Navigator.of(context).pop(); // Close review dialog
          Navigator.of(context).pop(); // Close project page
        },
      ),
    );
  }
}

class ReviewDialog extends StatefulWidget {
  final Ship ship;
  final Project project;
  final VoidCallback onReviewComplete;

  const ReviewDialog({
    super.key,
    required this.ship,
    required this.project,
    required this.onReviewComplete,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _step = 0;
  Set<int> _selectedChallenges = {};
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _overrideHoursController =
      TextEditingController();
  bool _isSubmitting = false;
  PlatformFile? _screenshotFile;
  String? _uploadedScreenshotUrl;
  bool _isUploadingScreenshot = false;
  int _technicalityRating = 0;
  int _functionalityRating = 0;
  int _uxRating = 0;

  @override
  void dispose() {
    _commentController.dispose();
    _overrideHoursController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    if (_commentController.text.trim().isEmpty) {
      GlobalNotificationService.instance.showError('Please provide a comment');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Parse override hours if provided
      double? overrideHours;
      if (_overrideHoursController.text.trim().isNotEmpty) {
        overrideHours = double.tryParse(_overrideHoursController.text.trim());
        if (overrideHours == null || overrideHours < 0) {
          GlobalNotificationService.instance.showError(
            'Invalid override hours value',
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }

      await ShipService.approveShip(
        shipId: widget.ship.id,
        reviewerId: UserService.currentUser?.id ?? '',
        comment: _commentController.text.trim(),
        challengesCompleted: _selectedChallenges.toList(),
        screenshotUrl: _uploadedScreenshotUrl ?? '',
        overrideHours: overrideHours,
        technicality: _technicalityRating,
        functionality: _functionalityRating,
        ux: _uxRating,
      );

      if (!mounted) return;
      GlobalNotificationService.instance.showSuccess(
        'Ship approved successfully!',
      );
      widget.onReviewComplete();
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to approve ship: $e',
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleDeny() async {
    if (_commentController.text.trim().isEmpty) {
      GlobalNotificationService.instance.showError(
        'Please provide a comment explaining why this ship was denied',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ShipService.denyShip(
        shipId: widget.ship.id,
        reviewerId: UserService.currentUser?.id ?? '',
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;
      GlobalNotificationService.instance.showSuccess('Ship denied');
      widget.onReviewComplete();
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError('Failed to deny ship: $e');
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.rate_review, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _step == 0
                        ? 'Bounties Completed'
                        : _step == 1
                        ? 'Screenshot & Hours'
                        : _step == 2
                        ? 'Rate Quality'
                        : 'Review Comment',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.close),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_step + 1) / 4,
              backgroundColor: colorScheme.surfaceContainerHigh,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _step == 0
                  ? _buildBountySelection()
                  : _step == 1
                  ? _buildScreenshotAndHoursStep()
                  : _step == 2
                  ? _buildRatingStep()
                  : _buildCommentStep(),
            ),
            const SizedBox(height: 16),
            _buildNavigationButtons(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildBountySelection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.ship.challengesRequested.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.info, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No bounties requested',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This ship has no bounties to review',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select which bounties were successfully completed:',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: widget.ship.challengesRequested.length,
            itemBuilder: (context, index) {
              final challenge = widget.ship.challengesRequested[index];
              final isSelected = _selectedChallenges.contains(challenge.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedChallenges.add(challenge.id);
                      } else {
                        _selectedChallenges.remove(challenge.id);
                      }
                    });
                  },
                  title: Text(
                    challenge.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(challenge.description, style: textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildChallengeBadge(
                            challenge.difficulty.toString().split('.').last,
                            _getDifficultyColor(challenge.difficulty),
                          ),
                          const SizedBox(width: 8),
                          _buildChallengeBadge(
                            challenge.type.toString().split('.').last,
                            colorScheme.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  activeColor: colorScheme.primary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return Colors.green;
      case ChallengeDifficulty.medium:
        return Colors.orange;
      case ChallengeDifficulty.hard:
        return Colors.red;
    }
  }

  Widget _buildRatingStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate the quality of this ship:',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Technicality Rating
          _buildRatingCategory(
            'Technicality',
            'Code quality, architecture, and technical implementation',
            _technicalityRating,
            (rating) => setState(() => _technicalityRating = rating),
            colorScheme,
            textTheme,
          ),
          const SizedBox(height: 24),

          // Functionality Rating
          _buildRatingCategory(
            'Functionality',
            'How well the OS works and meets requirements',
            _functionalityRating,
            (rating) => setState(() => _functionalityRating = rating),
            colorScheme,
            textTheme,
          ),
          const SizedBox(height: 24),

          // UX Rating
          _buildRatingCategory(
            'User Experience (UX)',
            'Interface design, usability, and overall user experience',
            _uxRating,
            (rating) => setState(() => _uxRating = rating),
            colorScheme,
            textTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCategory(
    String title,
    String description,
    int currentRating,
    Function(int) onRatingChanged,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final rating = index;
              final isSelected = currentRating == rating;

              return InkWell(
                onTap: () => onRatingChanged(rating),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        rating == 0 ? Symbols.close : Symbols.star,
                        color: isSelected
                            ? colorScheme.primary
                            : (rating == 0
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rating == 0 ? '0' : '$rating',
                        style: textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add your review comment:',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: _commentController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText:
                  'Provide feedback on the project, quality of work, bounties completed, etc...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotAndHoursStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screenshot upload section
          Text(
            'Upload OS Screenshot *',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Required: Upload a screenshot of the OS running',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
          const SizedBox(height: 12),
          if (_screenshotFile != null || _uploadedScreenshotUrl != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Symbols.image, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _screenshotFile?.name ?? 'Screenshot uploaded',
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _screenshotFile = null;
                          _uploadedScreenshotUrl = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _isUploadingScreenshot
                  ? null
                  : _handleScreenshotUpload,
              icon: _isUploadingScreenshot
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.upload),
              label: Text(
                _isUploadingScreenshot ? 'Uploading...' : 'Choose Screenshot',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          const SizedBox(height: 24),

          // Override hours section
          Text(
            'Override Hours (Optional):',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current tracked time: ${widget.ship.time.toStringAsFixed(1)} hours',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _overrideHoursController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Leave empty to use tracked time',
              labelText: 'Override hours',
              helperText: 'Only enter if you need to manually set the hours',
              prefixIcon: Icon(
                Symbols.schedule,
                color: colorScheme.onSurfaceVariant,
              ),
              suffixText: 'hrs',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScreenshotUpload() async {
    setState(() => _isUploadingScreenshot = true);

    try {
      final supabasePath =
          'project/${widget.ship.project}/ship_${widget.ship.id}/screenshot';
      final supabasePrivateUrl = await StorageService.uploadFileWithPicker(
        path: supabasePath,
      );

      if (!mounted) return;

      if (supabasePrivateUrl == 'User cancelled') {
        setState(() => _isUploadingScreenshot = false);
        return;
      }

      final supabasePublicUrl = await StorageService.getPublicUrl(
        path: supabasePrivateUrl,
      );

      if (!mounted) return;

      if (supabasePublicUrl == null) {
        GlobalNotificationService.instance.showError(
          'Failed to get public URL for screenshot',
        );
        setState(() => _isUploadingScreenshot = false);
        return;
      }

      setState(() {
        _uploadedScreenshotUrl = supabasePublicUrl;
        _isUploadingScreenshot = false;
      });

      GlobalNotificationService.instance.showSuccess(
        'Screenshot uploaded successfully!',
      );
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to upload screenshot: $e',
      );
      setState(() => _isUploadingScreenshot = false);
    }
  }

  Widget _buildNavigationButtons(ColorScheme colorScheme) {
    if (_step == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Next'),
          ),
        ],
      );
    }

    if (_step == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : () => setState(() => _step = 0),
            icon: const Icon(Symbols.arrow_back, size: 20),
            label: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => setState(() => _step = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Next'),
          ),
        ],
      );
    }

    if (_step == 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : () => setState(() => _step = 1),
            icon: const Icon(Symbols.arrow_back, size: 20),
            label: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => setState(() => _step = 3),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Next'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: _isSubmitting ? null : () => setState(() => _step = 2),
          icon: const Icon(Symbols.arrow_back, size: 20),
          label: const Text('Back'),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _handleDeny,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.close, size: 20),
              label: const Text('Deny'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleApprove,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.check, size: 20),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
