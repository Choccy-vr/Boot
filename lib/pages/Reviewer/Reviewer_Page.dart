import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:boot_app/services/ships/ship_service.dart';
import 'package:boot_app/services/ships/Boot_Ship.dart';
import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/project_service.dart';
import 'package:boot_app/services/challenges/Challenge.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:boot_app/services/notifications/notifications.dart';
import 'package:boot_app/pages/Projects/Project_Page.dart';
import 'package:boot_app/theme/responsive.dart';
import 'package:boot_app/widgets/shared_navigation_rail.dart';

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
      GlobalNotificationService.instance.showError(
        'Failed to load ships: $e',
      );
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
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              )
            : _unreviewedShips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Symbols.check_circle,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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

                        return _buildShipCard(ship, project, colorScheme, textTheme);
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
                      label: '${ship.challengesRequested.length} challenge${ship.challengesRequested.length == 1 ? '' : 's'}',
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
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
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
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
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
      body: ProjectDetailPage(project: widget.project),
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
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    if (_commentController.text.trim().isEmpty) {
      GlobalNotificationService.instance.showError(
        'Please provide a comment',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ShipService.approveShip(
        shipId: widget.ship.id,
        reviewerId: UserService.currentUser?.id ?? '',
        comment: _commentController.text.trim(),
        challengesCompleted: _selectedChallenges.toList(),
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
      GlobalNotificationService.instance.showSuccess(
        'Ship denied',
      );
      widget.onReviewComplete();
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to deny ship: $e',
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.rate_review,
                  color: colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _step == 0 ? 'Challenges Completed' : 'Review Comment',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.close),
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_step + 1) / 2,
              backgroundColor: colorScheme.surfaceContainerHigh,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _step == 0 ? _buildChallengeSelection() : _buildCommentStep(),
            ),
            const SizedBox(height: 16),
            _buildNavigationButtons(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeSelection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.ship.challengesRequested.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.info,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No challenges requested',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This ship has no challenges to review',
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
          'Select which challenges were successfully completed:',
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
                      Text(
                        challenge.description,
                        style: textTheme.bodySmall,
                      ),
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
              hintText: 'Provide feedback on the project, quality of work, challenges completed, etc...',
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
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: _isSubmitting ? null : () => setState(() => _step = 0),
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
