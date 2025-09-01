import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/theme/terminal_theme.dart';
import '/services/navigation_service.dart';
import '/services/users/User.dart';
import '/services/supabase/DB/supabase_db.dart';

class CreateProjectPage extends StatefulWidget {
  const CreateProjectPage({super.key});

  @override
  State<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage>
    with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  final String _headerText = "Initialize New OS Project";

  // Form controllers
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _repositoryController = TextEditingController();

  // State variables
  String _selectedOSType = 'custom';
  String _selectedArchitecture = 'x86_64';
  String _selectedBootloader = 'grub';
  bool _enableGitInit = true;
  bool _enableDockerSupport = false;
  bool _enableCICD = false;
  bool _isLoading = false;

  // Options maps
  final Map<String, String> _osTypes = {
    'custom': 'Custom OS',
    'linux': 'Linux-based',
    'microkernel': 'Microkernel',
    'monolithic': 'Monolithic Kernel',
    'hobbyos': 'Hobby OS',
  };

  final Map<String, String> _architectures = {
    'x86_64': 'x86-64 (64-bit)',
    'x86': 'x86 (32-bit)',
    'arm64': 'ARM64',
    'arm': 'ARM 32-bit',
    'riscv': 'RISC-V',
  };

  final Map<String, String> _bootloaders = {
    'grub': 'GRUB 2',
    'limine': 'Limine',
    'uefi': 'UEFI Direct',
    'multiboot': 'Multiboot',
    'custom': 'Custom Bootloader',
  };

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
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    _projectNameController.dispose();
    _descriptionController.dispose();
    _repositoryController.dispose();
    super.dispose();
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
        actions: [
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _createProject,
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
                : Icon(Symbols.rocket_launch, size: 18),
            label: Text(_isLoading ? 'Creating...' : 'Create Project'),
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProjectBasicsSection(colorScheme, textTheme),
                    const SizedBox(height: 24),
                    _buildArchitectureSection(colorScheme, textTheme),
                    const SizedBox(height: 24),
                    _buildAdvancedOptionsSection(colorScheme, textTheme),
                    const SizedBox(height: 24),
                    _buildSystemPreview(colorScheme, textTheme),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                'boot-terminal ~ ${UserService.currentUser?.username}@hackathon',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated project creation text
          AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              String displayText = _headerText.substring(
                0,
                _typewriterAnimation.value,
              );
              return RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '\$ mkdir ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                    TextSpan(
                      text: displayText,
                      style: textTheme.headlineMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          Text(
            'Configure your operating system project parameters',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectBasicsSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.folder, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Project Basics',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Project Name
            TextField(
              controller: _projectNameController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Project Name',
                hintText: 'MyAwesomeOS',
                prefixIcon: Icon(
                  Symbols.title,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your OS project...',
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
            const SizedBox(height: 16),

            // Repository URL (optional)
            TextField(
              controller: _repositoryController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Repository URL (Optional)',
                hintText: 'https://github.com/username/project',
                prefixIcon: Icon(
                  Symbols.link,
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

  Widget _buildArchitectureSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.settings, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'System Architecture',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // OS Type
            DropdownButtonFormField<String>(
              value: _selectedOSType,
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
            const SizedBox(height: 16),

            // Architecture
            DropdownButtonFormField<String>(
              value: _selectedArchitecture,
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
            const SizedBox(height: 16),

            // Bootloader
            DropdownButtonFormField<String>(
              value: _selectedBootloader,
              style: TextStyle(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surfaceContainerHigh,
              decoration: InputDecoration(
                labelText: 'Bootloader',
                prefixIcon: Icon(
                  Symbols.rocket_launch,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _bootloaders.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedBootloader = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsSection(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.tune, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Development Options',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: Text(
                'Initialize Git Repository',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'Set up version control from the start',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              value: _enableGitInit,
              onChanged: (value) => setState(() => _enableGitInit = value),
              activeColor: colorScheme.primary,
            ),

            SwitchListTile(
              title: Text(
                'Docker Support',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'Include Dockerfile and docker-compose setup',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              value: _enableDockerSupport,
              onChanged: (value) =>
                  setState(() => _enableDockerSupport = value),
              activeColor: colorScheme.primary,
            ),

            SwitchListTile(
              title: Text(
                'CI/CD Pipeline',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'GitHub Actions workflow for building and testing',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              value: _enableCICD,
              onChanged: (value) => setState(() => _enableCICD = value),
              activeColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemPreview(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.preview, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Project Preview',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '> Project Configuration Summary',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Name: ${_projectNameController.text.isEmpty ? 'MyAwesomeOS' : _projectNameController.text}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '• Type: ${_osTypes[_selectedOSType]}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '• Architecture: ${_architectures[_selectedArchitecture]}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '• Bootloader: ${_bootloaders[_selectedBootloader]}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_enableGitInit ||
                      _enableDockerSupport ||
                      _enableCICD) ...[
                    const SizedBox(height: 8),
                    Text(
                      '• Features: ${[if (_enableGitInit) 'Git', if (_enableDockerSupport) 'Docker', if (_enableCICD) 'CI/CD'].join(', ')}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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

    setState(() => _isLoading = true);

    try {
      // Here you would create the project in your database
      await SupabaseDB.InsertData(
        table: 'projects',
        data: {
          'name': _projectNameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'owner': UserService.currentUser?.id,
          'github_repo': _repositoryController.text.trim(),
          'os_type': _selectedOSType,
          'architecture': _selectedArchitecture,
          'bootloader': _selectedBootloader,
          'git_init': _enableGitInit,
          'docker_support': _enableDockerSupport,
          'cicd_enabled': _enableCICD,
          'status': 'building',
          'image_url': 'https://via.placeholder.com/400x300?text=OS+Project',
          'total_time': 0,
          'total_likes': 0,
          'level': 1,
          'awaiting_review': false,
          'reviewed': false,
        },
      );

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create project: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Row(
          children: [
            Icon(
              Symbols.check_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Project Created! 🚀',
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
              'Your OS project has been successfully initialized!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project Configuration:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Type: ${_osTypes[_selectedOSType]}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '• Architecture: ${_architectures[_selectedArchitecture]}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '• Bootloader: ${_bootloaders[_selectedBootloader]}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Awesome!',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
