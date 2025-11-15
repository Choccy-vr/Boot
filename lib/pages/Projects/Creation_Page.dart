import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:boot_app/services/misc/logger.dart';
import '/services/users/User.dart';
import '/services/hackatime/hackatime_service.dart';
import '/services/Projects/project_service.dart';
import '/services/navigation/navigation_service.dart';

class CreateProjectPage extends StatefulWidget {
  const CreateProjectPage({super.key});

  @override
  State<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage>
    with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  final String _headerText = "make build-os";
  static final RegExp _githubRepoRegex = RegExp(
    r'^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/?$',
  );

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _repositoryController = TextEditingController();

  String _selectedOSType = 'scratch';
  String _selectedArchitecture = 'x86_64';
  final List<String> _selectedHackatimeProjects = [];
  Set<String> _claimedHackatimeProjects = {};

  final Map<String, String> _osTypes = {
    'scratch': 'From Scratch (LFS, Buildroot, etc.)',
    'base': 'Based On Another Distro (Debian, Ubuntu, etc.)',
  };

  final Map<String, String> _architectures = {
    'x86_64': 'x86-64 (64-bit)',
    'x86': 'x86 (32-bit)',
  };
  List<HackatimeProject> _hackatimeProjects = [];

  @override
  void initState() {
    super.initState();
    _typewriterController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typewriterAnimation = IntTween(begin: 0, end: _headerText.length).animate(
      CurvedAnimation(parent: _typewriterController, curve: Curves.easeInOut),
    );
    _typewriterController.forward();
    _fetchHackatimeProjects();
    _loadExistingHackatimeAssignments();
  }

  Future<void> _fetchHackatimeProjects() async {
    final projects = await HackatimeService.fetchHackatimeProjects(
      userId: UserService.currentUser?.hackatimeID ?? 0,
      apiKey: UserService.currentUser?.hackatimeApiKey ?? '',
      context: context,
    );
    setState(() {
      _hackatimeProjects = projects;
      _selectedHackatimeProjects.removeWhere(
        (selected) => !_hackatimeProjects.any(
          (project) => project.name.toLowerCase() == selected.toLowerCase(),
        ),
      );
    });
  }

  Future<void> _loadExistingHackatimeAssignments() async {
    final userId = UserService.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      final projects = await ProjectService.getProjects(userId);
      final claimed = <String>{};
      for (final project in projects) {
        claimed.addAll(
          project.hackatimeProjects
              .map((name) => name.toLowerCase())
              .where((name) => name.isNotEmpty),
        );
      }
      setState(() {
        _claimedHackatimeProjects = claimed;
        _selectedHackatimeProjects.removeWhere(
          (name) => claimed.contains(name.toLowerCase()),
        );
      });
    } catch (e, stack) {
      AppLogger.error(
        'Failed to load existing Hackatime assignments',
        e,
        stack,
      );
    }
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    _projectNameController.dispose();
    _descriptionController.dispose();
    _repositoryController.dispose();
    super.dispose();
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
                'boot@ysws:~/projects',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              String displayText = _headerText.substring(
                0,
                _typewriterAnimation.value,
              );
              return Text(
                '\$ $displayText',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.secondary,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'gathering project requirements...',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectForm(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        _buildProjectBasicsSection(colorScheme, textTheme),
        const SizedBox(height: 24),
        _buildSystemConfigSection(colorScheme, textTheme),
        const SizedBox(height: 24),
        _buildHackatimeConfigSection(colorScheme, textTheme),
        const SizedBox(height: 24),
        _buildProjectPreview(colorScheme, textTheme),
        const SizedBox(height: 32),
        _buildCreateButton(colorScheme, textTheme),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProjectBasicsSection(
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
            Text(
              'Project Basics',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _projectNameController,
              maxLength: 25,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Project Name',
                hintText: 'MyAwesomeOS',
                helperText: '2–25 characters',
                prefixIcon: Icon(
                  Symbols.folder,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'A powerful operating system built from scratch...',
                helperText: '50–500 characters',
                alignLabelWithHint: true,
                prefixIcon: Icon(
                  Symbols.description,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _repositoryController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Repository URL',
                hintText: 'https://github.com/username/my-awesome-os',
                helperText: 'Must be a valid GitHub URL',
                prefixIcon: Icon(
                  Symbols.folder_data,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemConfigSection(
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
            Text(
              'System Configuration',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedOSType,
              style: TextStyle(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surfaceContainerHigh,
              decoration: InputDecoration(
                labelText: 'OS Type',
                prefixIcon: Icon(
                  Symbols.computer,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _osTypes.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedOSType = value!),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedArchitecture,
              style: TextStyle(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surfaceContainerHigh,
              decoration: InputDecoration(
                labelText: 'Target Architecture',
                prefixIcon: Icon(
                  Symbols.developer_board,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _architectures.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedArchitecture = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHackatimeConfigSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final hasAvailableProjects =
        _hackatimeProjects.isNotEmpty &&
        !(_hackatimeProjects.length == 1 &&
            _hackatimeProjects.first.name == 'No Projects Available');
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hackatime Configuration',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (!hasAvailableProjects)
              _buildNoHackatimeProjectsMessage(colorScheme, textTheme)
            else ...[
              _buildHackatimeInfoBanner(colorScheme, textTheme),
              const SizedBox(height: 16),
              _buildHackatimeProjectChips(colorScheme, textTheme),
              if (_selectedHackatimeProjects.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSelectedHackatimeSummary(colorScheme, textTheme),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoHackatimeProjectsMessage(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Symbols.info, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No Hackatime projects detected yet. Start tracking time in Hackatime and refresh to link it here.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHackatimeInfoBanner(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.timer, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select one or more Hackatime projects to link their tracked time to this build. Each Hackatime project can only be linked to a single Boot project.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHackatimeProjectChips(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final selectedSet = _selectedHackatimeProjects
        .map(_normalizeHackatimeName)
        .toSet();
    final projects = _hackatimeProjects
        .where((project) => project.name != 'No Projects Available')
        .toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: projects.map((project) {
        final normalizedName = _normalizeHackatimeName(project.name);
        final isSelected = selectedSet.contains(normalizedName);
        final isClaimedElsewhere = _claimedHackatimeProjects.contains(
          normalizedName,
        );
        final isDisabled = isClaimedElsewhere && !isSelected;
        final labelSecondary = project.text.isNotEmpty
            ? project.text
            : project.digital.isNotEmpty
            ? project.digital
            : '';

        return Tooltip(
          message: isDisabled
              ? 'Already linked to another Boot project'
              : isSelected
              ? 'Tap to unlink this Hackatime project'
              : 'Tap to link this Hackatime project',
          child: FilterChip(
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            selectedColor: colorScheme.primaryContainer,
            checkmarkColor: colorScheme.onPrimaryContainer,
            disabledColor: colorScheme.surfaceContainerHigh,
            backgroundColor: colorScheme.surfaceContainerLow,
            avatar: Icon(
              isDisabled
                  ? Symbols.block
                  : isSelected
                  ? Symbols.check
                  : Symbols.add,
              size: 18,
              color: isDisabled
                  ? colorScheme.onSurfaceVariant
                  : isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.primary,
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    project.name,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDisabled
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  if (labelSecondary.isNotEmpty)
                    Text(
                      labelSecondary,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            selected: isSelected,
            onSelected: isDisabled
                ? null
                : (selected) => _toggleHackatimeProject(project.name, selected),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedHackatimeSummary(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Linked Hackatime projects',
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedHackatimeProjects.map((projectName) {
            return InputChip(
              label: Text(projectName),
              onDeleted: () => _toggleHackatimeProject(projectName, false),
              avatar: Icon(Symbols.bolt, size: 18),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _toggleHackatimeProject(String projectName, bool shouldSelect) {
    final normalizedName = _normalizeHackatimeName(projectName);
    setState(() {
      if (shouldSelect) {
        final alreadySelected = _selectedHackatimeProjects.any(
          (name) => _normalizeHackatimeName(name) == normalizedName,
        );
        if (!alreadySelected) {
          _selectedHackatimeProjects.add(projectName);
        }
      } else {
        _selectedHackatimeProjects.removeWhere(
          (name) => _normalizeHackatimeName(name) == normalizedName,
        );
      }
    });
  }

  String _normalizeHackatimeName(String name) => name.trim().toLowerCase();

  bool _isValidGithubRepoUrl(String url) {
    if (url.isEmpty) return false;
    return _githubRepoRegex.hasMatch(url.trim());
  }

  void _showFormMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProjectPreview(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build Configuration Preview',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'checking build configuration...',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildConfigLine(
                    'TARGET',
                    _projectNameController.text.isEmpty
                        ? 'MyAwesomeOS'
                        : _projectNameController.text,
                    colorScheme,
                    textTheme,
                  ),
                  _buildConfigLine(
                    'TYPE',
                    _osTypes[_selectedOSType]!,
                    colorScheme,
                    textTheme,
                  ),
                  _buildConfigLine(
                    'ARCH',
                    _architectures[_selectedArchitecture]!,
                    colorScheme,
                    textTheme,
                  ),
                  _buildConfigLine(
                    'REPO',
                    _repositoryController.text.isEmpty
                        ? 'not specified'
                        : _repositoryController.text,
                    colorScheme,
                    textTheme,
                  ),
                  _buildConfigLine(
                    'HACK',
                    _selectedHackatimeProjects.isEmpty
                        ? 'not linked'
                        : _selectedHackatimeProjects.join(', '),
                    colorScheme,
                    textTheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigLine(
    String label,
    String value,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _createProject,
        icon: Icon(Symbols.rocket_launch, size: 20),
        label: Text(
          'Create Project',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    final title = _projectNameController.text.trim();
    final description = _descriptionController.text.trim();
    final repoUrl = _repositoryController.text.trim();
    final ownerId = UserService.currentUser?.id;

    if (ownerId == null || ownerId.isEmpty) {
      _showFormMessage('You need to be signed in to create a project.');
      return;
    }

    if (title.length < 2 || title.length > 25) {
      _showFormMessage('Project name must be between 2 and 25 characters.');
      return;
    }

    if (description.length < 50 || description.length > 500) {
      _showFormMessage('Description must be between 50 and 500 characters.');
      return;
    }

    if (!_isValidGithubRepoUrl(repoUrl)) {
      _showFormMessage('Enter a valid GitHub repository URL.');
      return;
    }

    if (_selectedHackatimeProjects.isEmpty) {
      _showFormMessage('Select at least one Hackatime project.');
      return;
    }

    final normalizedSelections = _selectedHackatimeProjects
        .map(_normalizeHackatimeName)
        .toSet();
    final conflictingSelections = normalizedSelections
        .where(_claimedHackatimeProjects.contains)
        .toList();
    if (conflictingSelections.isNotEmpty) {
      _showFormMessage(
        'One or more selected Hackatime projects are already linked to another build.',
      );
      return;
    }

    try {
      await ProjectService.createProject(
        title: title,
        description: description,
        imageURL: '',
        githubRepo: repoUrl,
        likes: 0,
        lastModified: DateTime.now(),
        awaitingReview: false,
        level: _selectedOSType,
        status: 'Building',
        reviewed: false,
        hackatimeProjects: _selectedHackatimeProjects,
        owner: ownerId,
      );
      if (!mounted) return;
      NavigationService.navigateTo(
        context: context,
        destination: AppDestination.project,
        colorScheme: Theme.of(context).colorScheme,
        textTheme: Theme.of(context).textTheme,
      );
    } catch (e, stack) {
      AppLogger.error('Failed to create project', e, stack);
      _showFormMessage('Something went wrong while creating your project.');
    }
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
            Icon(Symbols.add_circle, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Create Project',
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
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTerminalHeader(colorScheme, textTheme),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: _buildProjectForm(colorScheme, textTheme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
