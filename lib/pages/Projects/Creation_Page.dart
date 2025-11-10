import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
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

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _repositoryController = TextEditingController();

  String _selectedOSType = 'scratch';
  String _selectedArchitecture = 'x86_64';
  String _selectedHackatimeProject = 'No Project';

  final Map<String, String> _osTypes = {
    'scratch': 'From Scratch (LFS, Buildroot, etc.)',
    'base': 'Based On Another Distro (Debian, Ubuntu, etc.)',
  };

  final Map<String, String> _architectures = {
    'x86_64': 'x86-64 (64-bit)',
    'x86': 'x86 (32-bit)',
  };
  List<HackatimeProject> _hackatimeProjects = [
    HackatimeProject(
      name: 'No Projects Available',
      totalSeconds: 0,
      text: '',
      hours: 0,
      minutes: 0,
      digital: '',
    ),
  ];

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
  }

  Future<void> _fetchHackatimeProjects() async {
    final projects = await HackatimeService.fetchHackatimeProjects(
      userId: UserService.currentUser?.hackatimeID ?? 0,
      apiKey: UserService.currentUser?.hackatimeApiKey ?? '',
      context: context,
    );
    setState(() {
      _hackatimeProjects = projects;
      if (_hackatimeProjects.isNotEmpty) {
        final names = _hackatimeProjects.map((p) => p.name).toSet();
        if (!names.contains(_selectedHackatimeProject) ||
            _hackatimeProjects
                    .where((p) => p.name == _selectedHackatimeProject)
                    .length !=
                1) {
          _selectedHackatimeProject = _hackatimeProjects.first.name;
        }
      }
    });
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
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Project Name',
                hintText: 'MyAwesomeOS',
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
              maxLines: 3,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'A powerful operating system built from scratch...',
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
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Repository URL',
                hintText: 'https://github.com/username/my-awesome-os',
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
            DropdownButtonFormField<String>(
              initialValue:
                  (_hackatimeProjects.isEmpty ||
                      (_hackatimeProjects.length == 1 &&
                          _hackatimeProjects.first.name ==
                              'No Projects Available'))
                  ? 'No Projects Available'
                  : _selectedHackatimeProject,
              style: TextStyle(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surfaceContainerHigh,
              decoration: InputDecoration(
                labelText: 'Hackatime Project',
                prefixIcon: Icon(
                  Symbols.hourglass,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items:
                  (_hackatimeProjects.isEmpty ||
                      (_hackatimeProjects.length == 1 &&
                          _hackatimeProjects.first.name ==
                              'No Projects Available'))
                  ? [
                      DropdownMenuItem(
                        value: 'No Projects Available',
                        child: Text('No Projects Available'),
                      ),
                    ]
                  : _hackatimeProjects.map((project) {
                      return DropdownMenuItem(
                        value: project.name,
                        child: Text(
                          project.text.isNotEmpty
                              ? "${project.name} (${project.text})"
                              : project.name,
                        ),
                      );
                    }).toList(),
              onChanged:
                  (_hackatimeProjects.isEmpty ||
                      (_hackatimeProjects.length == 1 &&
                          _hackatimeProjects.first.name ==
                              'No Projects Available'))
                  ? null
                  : (value) =>
                        setState(() => _selectedHackatimeProject = value!),
            ),
          ],
        ),
      ),
    );
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
    if (_projectNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a project name')));
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a project description')),
      );
      return;
    }

    if (_repositoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a repository URL')));
      return;
    }

    if (_selectedHackatimeProject == 'No Project') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a Hackatime project')),
      );
      return;
    }

    await ProjectService.createProject(
      title: _projectNameController.text.trim(),
      description: _descriptionController.text.trim(),
      imageURL: '',
      githubRepo: _repositoryController.text.trim(),
      likes: 0,
      lastModified: DateTime.now(),
      awaitingReview: false,
      level: _selectedOSType,
      status: 'Building',
      reviewed: false,
      hackatimeProjects: _selectedHackatimeProject,
      owner: UserService.currentUser?.id,
    );
    if (!mounted) return;
    NavigationService.navigateTo(
      context: context,
      destination: AppDestination.project,
      colorScheme: Theme.of(context).colorScheme,
      textTheme: Theme.of(context).textTheme,
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
