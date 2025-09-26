import 'package:boot_app/services/ships/boot_ship.dart';
import 'package:flutter/material.dart';
import 'package:boot_app/services/Projects/project.dart';
import 'package:boot_app/services/devlog/devlog.dart';
import 'package:boot_app/services/devlog/devlog_service.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

List<Project> _extractProjects(List<dynamic> entries) {
  final projects = <Project>[];

  for (final entry in entries) {
    if (entry is Project) {
      projects.add(entry);
      continue;
    }

    if (entry is Map<Ship, Project>) {
      if (entry.isNotEmpty) {
        projects.add(entry.values.first);
      } else {
        AppLogger.warning('Empty ship-project pair encountered on vote page');
      }
      continue;
    }

    if (entry != null) {
      AppLogger.warning('Unsupported vote entry type: ${entry.runtimeType}');
    }
  }

  return projects;
}

class VotePage extends StatefulWidget {
  final List<Project> projects;

  VotePage({Key? key, required List<dynamic> projects})
    : projects = _extractProjects(projects),
      super(key: key);

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  List<Devlog> project1Devlogs = [];
  List<Devlog> project2Devlogs = [];
  bool isLoading = true;
  int? selectedProject;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevlogs();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadDevlogs() async {
    if (widget.projects.length >= 2) {
      try {
        final devlogs1 = await DevlogService.getDevlogsByProjectId(
          widget.projects[0].id.toString(),
        );
        final devlogs2 = await DevlogService.getDevlogsByProjectId(
          widget.projects[1].id.toString(),
        );

        setState(() {
          project1Devlogs = devlogs1.take(3).toList();
          project2Devlogs = devlogs2.take(3).toList();
          isLoading = false;
        });
      } catch (e, stack) {
        AppLogger.error('Failed to load devlogs for vote page', e, stack);
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    if (widget.projects.length < 2) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Vote', style: textTheme.headlineSmall),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.ballot, size: 64, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Not enough projects to vote on',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Come back later when more people have submitted their projects!',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Vote', style: textTheme.headlineSmall),
        backgroundColor: colorScheme.surface,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Which project is better?',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 800) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildProjectCard(
                                widget.projects[0],
                                project1Devlogs,
                                0,
                                colorScheme,
                                textTheme,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildProjectCard(
                                widget.projects[1],
                                project2Devlogs,
                                1,
                                colorScheme,
                                textTheme,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildProjectCard(
                              widget.projects[0],
                              project1Devlogs,
                              0,
                              colorScheme,
                              textTheme,
                            ),
                            const SizedBox(height: 16),
                            _buildProjectCard(
                              widget.projects[1],
                              project2Devlogs,
                              1,
                              colorScheme,
                              textTheme,
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 32),

                  _buildVotingSection(colorScheme, textTheme),
                ],
              ),
            ),
    );
  }

  Widget _buildProjectCard(
    Project project,
    List<Devlog> devlogs,
    int projectIndex,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isSelected = selectedProject == projectIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedProject = projectIndex;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project.imageURL.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: colorScheme.surfaceVariant,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      project.imageURL,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        AppLogger.warning(
                          'Failed to load project image: ${project.imageURL}',
                        );
                        return Container(
                          color: colorScheme.surfaceVariant,
                          child: Icon(
                            Symbols.image,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: colorScheme.surfaceVariant,
                  ),
                  child: Icon(
                    Symbols.image,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

              const SizedBox(height: 16),

              Text(
                project.title,
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                project.description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(Symbols.schedule, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    project.readableTime,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Symbols.favorite, size: 16, color: colorScheme.error),
                  const SizedBox(width: 4),
                  Text(
                    '${project.likes}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Symbols.code, size: 16, color: colorScheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    project.level,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              if (devlogs.isNotEmpty) ...[
                Text(
                  'Recent Updates',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...devlogs.map(
                  (devlog) => _buildDevlogItem(devlog, colorScheme, textTheme),
                ),
              ] else
                Text(
                  'No recent updates',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevlogItem(
    Devlog devlog,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  devlog.title,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatDate(devlog.createdAt),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            devlog.description,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (devlog.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: devlog.mediaUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: colorScheme.surfaceVariant,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        devlog.mediaUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          AppLogger.warning(
                            'Failed to load devlog media: ${devlog.mediaUrls[index]}',
                          );
                          return Icon(
                            Symbols.image,
                            color: colorScheme.onSurfaceVariant,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVotingSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cast Your Vote',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Which project impressed you more? Select one above and tell us why:',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _feedbackController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Share your thoughts on why this project is better, potential improvements, bugs you noticed, or any other feedback...',
              hintStyle: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.primary),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedProject != null ? _submitVote : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Symbols.how_to_vote),
              label: Text(
                selectedProject != null
                    ? 'Submit Vote for ${widget.projects[selectedProject!].title}'
                    : 'Select a project to vote',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _submitVote() {
    if (selectedProject == null) return;

    try {
      final selectedProjectData = widget.projects[selectedProject!];
      final feedback = _feedbackController.text.trim();

      AppLogger.info(
        'Vote submitted for project ${selectedProjectData.id}: ${selectedProjectData.title}',
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vote Submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You voted for: ${selectedProjectData.title}'),
              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Feedback: $feedback'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to submit vote', e, stack);
    }
  }
}
