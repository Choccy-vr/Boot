import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:boot_app/services/misc/logger.dart';
import '/services/users/User.dart';
import '/services/hackatime/hackatime_service.dart';
import '/services/Projects/project_service.dart';
import '/services/navigation/navigation_service.dart';
import '/services/notifications/notifications.dart';
import '/widgets/shared_navigation_rail.dart';

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

  // Support multiple git hosting platforms
  static final RegExp _gitRepoRegex = RegExp(
    r'^https?:\/\/(github\.com|gitlab\.com|bitbucket\.org|gitea\.io|codeberg\.org|sr\.ht|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
    r'\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/?$',
  );

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _repositoryController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  String _selectedOSType = 'scratch';
  String _selectedArchitecture = 'x86_64';
  final List<String> _selectedHackatimeProjects = [];
  final List<String> _projectTags = [];
  List<String> _filteredSuggestions = [];
  bool _showTagSuggestions = false;
  TextEditingController? _currentTagController;
  Set<String> _claimedHackatimeProjects = {};
  final TextEditingController _hackatimeSearchController =
      TextEditingController();
  List<HackatimeProject> _filteredHackatimeProjects = [];
  bool _showNameValidation = false;
  bool _showDescriptionValidation = false;
  bool _showRepoValidation = false;
  bool _showHackatimeValidation = false;

  final Map<String, String> _osTypes = {
    'scratch': 'From Scratch (LFS, Buildroot, etc.)',
    'base': 'Based On Another Distro (Debian, Ubuntu, etc.)',
  };

  final Map<String, String> _architectures = {
    'x86_64': 'x86-64',
    'x86': 'x86 (32-bit)',
  };

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
    'x86',
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
  ];
  List<HackatimeProject> _hackatimeProjects = [];

  String? get _projectNameError {
    final text = _projectNameController.text.trim();
    if (text.isEmpty) return 'Project name is required';
    if (text.length < 2) return 'Minimum 2 characters';
    if (text.length > 25) return 'Maximum 25 characters';
    return null;
  }

  String? get _descriptionError {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) return 'Description is required';
    if (text.length < 50) return 'Minimum 50 characters';
    if (text.length > 500) return 'Maximum 500 characters';
    return null;
  }

  String? get _repositoryError {
    final text = _repositoryController.text.trim();
    if (text.isEmpty) return 'Repository URL is required';
    if (!_isValidGitRepoUrl(text))
      return 'Enter a valid Git repository URL (GitHub, GitLab, Bitbucket, etc.)';
    return null;
  }

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
    // Load both data sources in parallel for faster page load
    _loadHackatimeData();
  }

  Future<void> _loadHackatimeData() async {
    // Run both fetches in parallel using Future.wait
    await Future.wait([
      _fetchHackatimeProjects(),
      _loadExistingHackatimeAssignments(),
    ]);
  }

  Future<void> _fetchHackatimeProjects() async {
    try {
      final projects = await HackatimeService.fetchHackatimeProjects(
        slackUserId: UserService.currentUser?.slackUserId ?? '',
        context: context,
      );
      if (!mounted) return;
      setState(() {
        _hackatimeProjects = projects;
        _filteredHackatimeProjects = projects;
        _selectedHackatimeProjects.removeWhere(
          (selected) => !_hackatimeProjects.any(
            (project) => project.name.toLowerCase() == selected.toLowerCase(),
          ),
        );
      });
    } catch (e, stack) {
      AppLogger.error('Failed to fetch Hackatime projects', e, stack);
      // Set empty list on error so UI doesn't hang
      if (!mounted) return;
      setState(() {
        _hackatimeProjects = [];
        _filteredHackatimeProjects = [];
      });
    }
  }

  void _filterHackatimeProjects(String query) {
    if (query.isEmpty) {
      setState(() => _filteredHackatimeProjects = _hackatimeProjects);
    } else {
      final lowerQuery = query.toLowerCase();
      setState(() {
        _filteredHackatimeProjects = _hackatimeProjects.where((project) {
          return project.name.toLowerCase().contains(lowerQuery);
        }).toList();
      });
    }
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
      if (!mounted) return;
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
              onChanged: (_) => setState(() => _showNameValidation = true),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Project Name',
                hintText: 'MyAwesomeOS',
                helperText: _showNameValidation && _projectNameError != null
                    ? null
                    : '2–25 characters',
                errorText: _showNameValidation ? _projectNameError : null,
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
              onChanged: (_) =>
                  setState(() => _showDescriptionValidation = true),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'A powerful operating system built from scratch...',
                helperText:
                    _showDescriptionValidation && _descriptionError != null
                    ? null
                    : '50–500 characters',
                errorText: _showDescriptionValidation
                    ? _descriptionError
                    : null,
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
              onChanged: (_) => setState(() => _showRepoValidation = true),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Repository URL',
                hintText: 'https://github.com/username/my-awesome-os',
                helperText: _showRepoValidation && _repositoryError != null
                    ? null
                    : 'Any valid Git hosting URL (GitHub, GitLab, Bitbucket, etc.)',
                errorText: _showRepoValidation ? _repositoryError : null,
                prefixIcon: Icon(
                  Symbols.folder_data,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Tags',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _popularTags
                      .where((tag) => !_projectTags.contains(tag))
                      .toList();
                }
                final input = textEditingValue.text.toLowerCase();
                return _popularTags
                    .where(
                      (tag) =>
                          tag.toLowerCase().contains(input) &&
                          !_projectTags.contains(tag),
                    )
                    .toList();
              },
              onSelected: (String selection) {
                setState(() {
                  if (!_projectTags.contains(selection)) {
                    _projectTags.add(selection);
                  }
                });
                _currentTagController?.clear();
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    _currentTagController = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLength: 20,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Search and add tags',
                        hintText: 'Start typing (e.g., "LFS", "Ubuntu")',
                        helperText: '${_projectTags.length} tag(s) added',
                        prefixIcon: Icon(
                          Symbols.label,
                          color: colorScheme.onSurfaceVariant,
                        ),
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
                        if (value.isNotEmpty && !_projectTags.contains(value)) {
                          setState(() {
                            _projectTags.add(value.trim());
                            controller.clear();
                          });
                        }
                      },
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 300,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                            hoverColor: colorScheme.surfaceContainerHighest,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_projectTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Selected Tags',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _projectTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() => _projectTags.remove(tag));
                    },
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  );
                }).toList(),
              ),
            ],
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
              TextField(
                controller: _hackatimeSearchController,
                onChanged: _filterHackatimeProjects,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Search Hackatime Projects',
                  hintText: 'Filter by project name...',
                  prefixIcon: Icon(
                    Symbols.search,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: _hackatimeSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Symbols.clear),
                          onPressed: () {
                            _hackatimeSearchController.clear();
                            _filterHackatimeProjects('');
                          },
                        )
                      : null,
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
              const SizedBox(height: 16),
              _buildHackatimeProjectChips(colorScheme, textTheme),
              if (_selectedHackatimeProjects.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSelectedHackatimeSummary(colorScheme, textTheme),
              ],
              if (_showHackatimeValidation &&
                  _selectedHackatimeProjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Symbols.error, size: 18, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select at least one Hackatime project to continue.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    final projects = _filteredHackatimeProjects
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
      _showHackatimeValidation = true;
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

  bool _isValidGitRepoUrl(String url) {
    if (url.isEmpty) return false;
    return _gitRepoRegex.hasMatch(url.trim());
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

    setState(() {
      _showNameValidation = true;
      _showDescriptionValidation = true;
      _showRepoValidation = true;
      _showHackatimeValidation = true;
    });

    if (ownerId == null || ownerId.isEmpty) {
      GlobalNotificationService.instance.showError(
        'You need to be signed in to create a project.',
      );
      return;
    }

    final nameError = _projectNameError;
    if (nameError != null) {
      GlobalNotificationService.instance.showError(nameError);
      return;
    }

    final descriptionError = _descriptionError;
    if (descriptionError != null) {
      GlobalNotificationService.instance.showError(descriptionError);
      return;
    }

    final repoError = _repositoryError;
    if (repoError != null) {
      GlobalNotificationService.instance.showError(repoError);
      return;
    }

    if (_selectedHackatimeProjects.isEmpty) {
      GlobalNotificationService.instance.showError(
        'Select at least one Hackatime project.',
      );
      return;
    }

    final normalizedSelections = _selectedHackatimeProjects
        .map(_normalizeHackatimeName)
        .toSet();
    final conflictingSelections = normalizedSelections
        .where(_claimedHackatimeProjects.contains)
        .toList();
    if (conflictingSelections.isNotEmpty) {
      GlobalNotificationService.instance.showError(
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
        lastModified: DateTime.now(),
        awaitingReview: false,
        level: _selectedOSType,
        status: 'Building',
        reviewed: false,
        hackatimeProjects: _selectedHackatimeProjects,
        owner: ownerId,
        tags: _projectTags,
      );
      if (!mounted) return;
      GlobalNotificationService.instance.showSuccess(
        'Project created! Redirecting to your build...',
      );
      NavigationService.navigateTo(
        context: context,
        destination: AppDestination.project,
        colorScheme: Theme.of(context).colorScheme,
        textTheme: Theme.of(context).textTheme,
      );
    } catch (e, stack) {
      AppLogger.error('Failed to create project', e, stack);
      GlobalNotificationService.instance.showError(
        'Something went wrong while creating your project.',
      );
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.add_circle, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Create Project',
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
            Container(
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
          ],
        ),
      ),
    );
  }
}
