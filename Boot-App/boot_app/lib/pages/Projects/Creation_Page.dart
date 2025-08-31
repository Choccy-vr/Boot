import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/theme/terminal_theme.dart';
import '/services/navigation_service.dart';

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

  // OS Type options
  final Map<String, String> _osTypes = {
    'custom': 'Custom OS (from scratch)',
    'linux': 'Linux Distribution',
    'microkernel': 'Microkernel',
    'rtos': 'Real-Time OS',
    'embedded': 'Embedded System',
    'experimental': 'Experimental/Research',
  };

  final Map<String, String> _architectures = {
    'x86_64': 'x86_64 (64-bit)',
    'x86': 'x86 (32-bit)',
    'arm64': 'ARM64 (AArch64)',
    'arm': 'ARM (32-bit)',
    'riscv': 'RISC-V',
  };

  final Map<String, String> _bootloaders = {
    'grub': 'GRUB (GNU GRand Unified Bootloader)',
    'limine': 'Limine Bootloader',
    'syslinux': 'SYSLINUX',
    'custom': 'Custom Bootloader',
    'none': 'No Bootloader',
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
        title: const Text('Create Project'),
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: colorScheme.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Terminal Header
              _buildTerminalHeader(colorScheme, textTheme),
              const SizedBox(height: 24),

              // Project Configuration Form
              _buildProjectForm(colorScheme, textTheme),
              const SizedBox(height: 24),

              // Advanced Options
              _buildAdvancedOptions(colorScheme, textTheme),
              const SizedBox(height: 24),

              // Create Button
              _buildCreateButton(colorScheme, textTheme),
            ],
          ),
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
                'boot-terminal ~ project-wizard@hackathon',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated header text
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
            'Configure your OS project settings',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectForm(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.folder_code, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Project Configuration',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Responsive form layout
            LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 600;

                if (isMobile) {
                  return Column(
                    children: _buildFormFields(colorScheme, textTheme),
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormFields(colorScheme, textTheme)[0],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFormFields(colorScheme, textTheme)[1],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFormFields(colorScheme, textTheme)[2],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormFields(colorScheme, textTheme)[3],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFormFields(colorScheme, textTheme)[4],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFormFields(colorScheme, textTheme)[5],
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormFields(ColorScheme colorScheme, TextTheme textTheme) {
    return [
      // Project Name
      TextField(
        controller: _projectNameController,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: 'Project Name',
          hintText: 'my-awesome-os',
          prefixIcon: Icon(Symbols.code, color: colorScheme.onSurfaceVariant),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // OS Type Dropdown
      DropdownButtonFormField<String>(
        value: _selectedOSType,
        style: TextStyle(color: colorScheme.onSurface),
        dropdownColor: colorScheme.surfaceContainerHigh,
        decoration: InputDecoration(
          labelText: 'OS Type',
          prefixIcon: Icon(Symbols.memory, color: colorScheme.onSurfaceVariant),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: _osTypes.entries.map((entry) {
          return DropdownMenuItem(value: entry.key, child: Text(entry.value));
        }).toList(),
        onChanged: (value) => setState(() => _selectedOSType = value!),
      ),

      // Description
      TextField(
        controller: _descriptionController,
        style: TextStyle(color: colorScheme.onSurface),
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Description',
          hintText: 'Describe your OS project...',
          alignLabelWithHint: true,
          prefixIcon: Icon(
            Symbols.description,
            color: colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: _architectures.entries.map((entry) {
          return DropdownMenuItem(value: entry.key, child: Text(entry.value));
        }).toList(),
        onChanged: (value) => setState(() => _selectedArchitecture = value!),
      ),

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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: _bootloaders.entries.map((entry) {
          return DropdownMenuItem(value: entry.key, child: Text(entry.value));
        }).toList(),
        onChanged: (value) => setState(() => _selectedBootloader = value!),
      ),

      // Repository URL
      TextField(
        controller: _repositoryController,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: 'Repository URL (Optional)',
          hintText: 'https://github.com/username/my-os',
          prefixIcon: Icon(
            Symbols.folder_data,
            color: colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ];
  }

  Widget _buildAdvancedOptions(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.settings, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Advanced Options',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Responsive options layout
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      _buildOptionTile(
                        'Initialize Git Repository',
                        'Set up version control for your project',
                        Symbols.source,
                        _enableGitInit,
                        (value) => setState(() => _enableGitInit = value),
                        colorScheme,
                        textTheme,
                      ),
                      _buildOptionTile(
                        'Docker Support',
                        'Include Docker configuration for development',
                        Symbols.developer_mode,
                        _enableDockerSupport,
                        (value) => setState(() => _enableDockerSupport = value),
                        colorScheme,
                        textTheme,
                      ),
                      _buildOptionTile(
                        'CI/CD Pipeline',
                        'Set up automated testing and deployment',
                        Symbols.build,
                        _enableCICD,
                        (value) => setState(() => _enableCICD = value),
                        colorScheme,
                        textTheme,
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildOptionTile(
                              'Initialize Git Repository',
                              'Set up version control for your project',
                              Symbols.source,
                              _enableGitInit,
                              (value) => setState(() => _enableGitInit = value),
                              colorScheme,
                              textTheme,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildOptionTile(
                              'Docker Support',
                              'Include Docker configuration for development',
                              Symbols.developer_mode,
                              _enableDockerSupport,
                              (value) =>
                                  setState(() => _enableDockerSupport = value),
                              colorScheme,
                              textTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildOptionTile(
                        'CI/CD Pipeline',
                        'Set up automated testing and deployment',
                        Symbols.build,
                        _enableCICD,
                        (value) => setState(() => _enableCICD = value),
                        colorScheme,
                        textTheme,
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      color: colorScheme.surfaceContainerLow,
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, color: colorScheme.tertiary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildCreateButton(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleCreateProject,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onPrimary,
                  ),
                ),
              )
            : Icon(Symbols.rocket_launch),
        label: Text(
          _isLoading ? 'Creating Project...' : 'Initialize Project',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateProject() async {
    if (_projectNameController.text.trim().isEmpty) {
      _showError('Please enter a project name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate project creation process
      await Future.delayed(Duration(seconds: 2));

      // Show success dialog
      await _showSuccessDialog();

      // Navigate back or to project page
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to create project: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        title: Row(
          children: [
            Icon(Symbols.error, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text(
              'Error',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainer,
        title: Row(
          children: [
            Icon(Symbols.check_circle, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Project Created! 🚀',
              style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your OS project "${_projectNameController.text}" has been successfully initialized!',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
                    'Project Configuration:',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
