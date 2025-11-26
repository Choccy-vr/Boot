/*import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '/services/Projects/Project.dart';
import '/services/Projects/project_service.dart';
import '/services/notifications/notifications.dart';
import '/theme/responsive.dart';
import '/theme/terminal_theme.dart';

class ProjectSetupPage extends StatefulWidget {
  final Project project;

  const ProjectSetupPage({super.key, required this.project});

  @override
  State<ProjectSetupPage> createState() => _ProjectSetupPageState();
}

class _ProjectSetupPageState extends State<ProjectSetupPage> {
  late Project _project;
  final TextEditingController _isoUrlController = TextEditingController();
  String? _isoSize;
  String? _isoError;
  bool _showAdvanced = false; // ignore: unused_field

  // QEMU Configuration
  int _memoryMB = 512;
  int _cpuCores = 2;
  String _bootDevice = 'cdrom';
  bool _enableKVM = true;
  bool _enableGraphics = true;
  String _networkMode = 'user';
  String _diskInterface = 'ide';
  int _vhdSizeGB = 10;

  // Advanced manual options
  final TextEditingController _advancedOptionsController =
      TextEditingController();
  String? _advancedError;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _isoUrlController.text = _project.isoUrl;

    // Parse existing QEMU command if available
    if (_project.qemuCMD.isNotEmpty) {
      _parseExistingQemuCommand(_project.qemuCMD);
    }
  }

  @override
  void dispose() {
    _isoUrlController.dispose();
    _advancedOptionsController.dispose();
    super.dispose();
  }

  void _parseExistingQemuCommand(String cmd) {
    // Parse memory
    final memMatch = RegExp(r'-m (\d+)').firstMatch(cmd);
    if (memMatch != null) {
      _memoryMB = int.tryParse(memMatch.group(1)!) ?? 512;
    }

    // Parse CPU cores
    final cpuMatch = RegExp(r'-smp (\d+)').firstMatch(cmd);
    if (cpuMatch != null) {
      _cpuCores = int.tryParse(cpuMatch.group(1)!) ?? 2;
    }

    // Parse boot device
    if (cmd.contains('-boot d')) {
      _bootDevice = 'cdrom';
    } else if (cmd.contains('-boot c')) {
      _bootDevice = 'hdd';
    }

    // Check for KVM
    _enableKVM = cmd.contains('-enable-kvm');

    // Check for graphics
    _enableGraphics = !cmd.contains('-nographic');

    // Parse network mode
    if (cmd.contains('user')) {
      _networkMode = 'user';
    } else if (cmd.contains('tap')) {
      _networkMode = 'tap';
    } else if (cmd.contains('none')) {
      _networkMode = 'none';
    }
  }

  String _generateQemuCommand() {
    final List<String> parts = [];

    // Base command
    parts.add('qemu-system-x86_64');

    // Memory
    parts.add('-m $_memoryMB');

    // CPU cores
    parts.add('-smp $_cpuCores');

    // Boot device
    parts.add('-boot ${_bootDevice == 'cdrom' ? 'd' : 'c'}');

    // KVM
    if (_enableKVM) {
      parts.add('-enable-kvm');
    }

    // Graphics
    if (!_enableGraphics) {
      parts.add('-nographic');
    }

    // Network
    if (_networkMode != 'none') {
      parts.add('-netdev $_networkMode,id=net0');
      parts.add('-device e1000,netdev=net0');
    }

    // CD-ROM with ISO (locked)
    parts.add('-cdrom \${ISO_PATH}');

    // Virtual hard drive (locked)
    if (_vhdSizeGB > 0) {
      parts.add('-hda \${HDD_PATH}');
    }

    // Disk interface
    if (_diskInterface != 'ide') {
      parts.add('-device $_diskInterface');
    }

    // Advanced options
    final advancedText = _advancedOptionsController.text.trim();
    if (advancedText.isNotEmpty) {
      // Validate advanced options
      if (_containsForbiddenOptions(advancedText)) {
        return parts.join(' ');
      }
      parts.add(advancedText);
    }

    return parts.join(' ');
  }

  bool _containsForbiddenOptions(String options) {
    final forbidden = [
      '-cdrom',
      '-hda',
      '-hdb',
      '-hdc',
      '-hdd',
      '-drive',
      'ISO_PATH',
      'HDD_PATH',
    ];
    final lowerOptions = options.toLowerCase();

    for (final opt in forbidden) {
      if (lowerOptions.contains(opt.toLowerCase())) {
        setState(() {
          _advancedError = 'Cannot modify ISO or hard drive options';
        });
        return true;
      }
    }

    setState(() {
      _advancedError = null;
    });
    return false;
  }

  Future<void> _saveConfiguration() async {
    // Validate ISO URL
    if (_isoUrlController.text.trim().isEmpty) {
      GlobalNotificationService.instance.showError('Please provide an ISO URL');
      return;
    }

    if (_isoError != null) {
      GlobalNotificationService.instance.showError('Please fix ISO URL errors');
      return;
    }

    // Check advanced options
    if (_advancedError != null) {
      GlobalNotificationService.instance.showError(
        'Please fix advanced options errors',
      );
      return;
    }

    try {
      _project.isoUrl = _isoUrlController.text.trim();
      _project.qemuCMD = _generateQemuCommand();

      await ProjectService.updateProject(_project);

      if (!mounted) return;
      GlobalNotificationService.instance.showSuccess(
        'Configuration saved successfully!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      GlobalNotificationService.instance.showError(
        'Failed to save configuration: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Project Setup',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: Responsive.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTerminalHeader(colorScheme, textTheme),
            SizedBox(height: Responsive.spacing(context)),
            _buildIsoSection(colorScheme, textTheme),
            SizedBox(height: Responsive.spacing(context)),
            _buildQemuSection(colorScheme, textTheme),
            SizedBox(height: Responsive.spacing(context)),
            _buildCommandPreview(colorScheme, textTheme),
            SizedBox(height: Responsive.spacing(context)),
            _buildSaveButton(colorScheme, textTheme),
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
                'boot@ysws:~/projects/${_project.title.toLowerCase().replaceAll(' ', '_')}/setup',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$ ./configure.sh',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure your OS for testing and deployment',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIsoSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.cloud_download,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'ISO Download Link',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(
                    text: 'Where can we find the download link to your ',
                  ),
                  TextSpan(
                    text: 'latest',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const TextSpan(text: ' revision?'),
                  const TextSpan(text: ' Note: This must be the '),
                  TextSpan(
                    text: 'download',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const TextSpan(text: ' link.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _isoUrlController,
              decoration: InputDecoration(
                labelText: 'ISO URL',
                hintText: 'https://example.com/myos-latest.iso',
                prefixIcon: Icon(Symbols.link, color: colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.error, width: 2),
                ),
                errorText: _isoError,
              ),
              onChanged: (value) {
                setState(() {
                  _isoError = null;
                  _isoSize = null;
                });
              },
            ),
            if (_isoSize != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Symbols.info, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'ISO Size: $_isoSize',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Symbols.check, color: TerminalColors.green, size: 20),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQemuSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.settings, color: colorScheme.secondary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'QEMU Configuration',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This is the command that will run your OS so people can test it.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Memory Configuration
            _buildConfigOption(
              label: 'Memory (RAM) - Recommended',
              subtitle: 'Testers can adjust this when running',
              icon: Symbols.memory,
              colorScheme: colorScheme,
              textTheme: textTheme,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _memoryMB.toDouble(),
                      min: 128,
                      max: 8192,
                      divisions: 63,
                      label: '$_memoryMB MB',
                      onChanged: (value) {
                        setState(() {
                          _memoryMB = value.toInt();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_memoryMB MB',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CPU Cores
            _buildConfigOption(
              label: 'CPU Cores - Recommended',
              subtitle: 'Testers can adjust this when running',
              icon: Symbols.developer_board,
              colorScheme: colorScheme,
              textTheme: textTheme,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _cpuCores.toDouble(),
                      min: 1,
                      max: 16,
                      divisions: 15,
                      label: '$_cpuCores cores',
                      onChanged: (value) {
                        setState(() {
                          _cpuCores = value.toInt();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_cpuCores cores',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Boot Device
            _buildConfigOption(
              label: 'Boot Device',
              icon: Symbols.restart_alt,
              colorScheme: colorScheme,
              textTheme: textTheme,
              child: DropdownButtonFormField<String>(
                value: _bootDevice,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 'cdrom', child: Text('CD-ROM (ISO)')),
                  DropdownMenuItem(value: 'hdd', child: Text('Hard Disk')),
                ],
                onChanged: (value) {
                  setState(() {
                    _bootDevice = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Network Mode
            _buildConfigOption(
              label: 'Network Mode',
              icon: Symbols.wifi,
              colorScheme: colorScheme,
              textTheme: textTheme,
              child: DropdownButtonFormField<String>(
                value: _networkMode,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'user',
                    child: Text('User Mode (NAT)'),
                  ),
                  DropdownMenuItem(value: 'tap', child: Text('TAP (Bridge)')),
                  DropdownMenuItem(value: 'none', child: Text('No Network')),
                ],
                onChanged: (value) {
                  setState(() {
                    _networkMode = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Disk Interface
            _buildConfigOption(
              label: 'Disk Interface',
              icon: Symbols.storage,
              colorScheme: colorScheme,
              textTheme: textTheme,
              child: DropdownButtonFormField<String>(
                value: _diskInterface,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 'ide', child: Text('IDE')),
                  DropdownMenuItem(
                    value: 'virtio-blk',
                    child: Text('VirtIO Block'),
                  ),
                  DropdownMenuItem(value: 'ahci', child: Text('AHCI (SATA)')),
                ],
                onChanged: (value) {
                  setState(() {
                    _diskInterface = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // VHD Size
            _buildConfigOption(
              label: 'Virtual Hard Disk Size',
              subtitle: 'Set to 0 GB to disable virtual hard disk',
              icon: Symbols.hard_drive,
              colorScheme: colorScheme,
              textTheme: textTheme,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _vhdSizeGB.toDouble(),
                      min: 0,
                      max: 32,
                      divisions: 32,
                      label: _vhdSizeGB == 0 ? 'Disabled' : '$_vhdSizeGB GB',
                      onChanged: (value) {
                        setState(() {
                          _vhdSizeGB = value.toInt();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _vhdSizeGB == 0
                          ? colorScheme.errorContainer
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _vhdSizeGB == 0 ? 'Disabled' : '$_vhdSizeGB GB',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _vhdSizeGB == 0
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Toggle Options
            _buildConfigOption(
              label: 'Additional Options',
              icon: Symbols.toggle_on,
              colorScheme: colorScheme,
              textTheme: textTheme,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Enable KVM (Hardware Acceleration)'),
                    subtitle: Text('Faster performance on Linux hosts'),
                    value: _enableKVM,
                    onChanged: (value) {
                      setState(() {
                        _enableKVM = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text('Enable Graphics'),
                    subtitle: Text('Disable for headless/text-only testing'),
                    value: _enableGraphics,
                    onChanged: (value) {
                      setState(() {
                        _enableGraphics = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Advanced Section
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showAdvanced = !_showAdvanced;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.code,
                            color: TerminalColors.yellow,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Advanced Options',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showAdvanced
                                ? Symbols.expand_less
                                : Symbols.expand_more,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAdvanced) ...[
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TerminalColors.yellow.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: TerminalColors.yellow.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Symbols.warning,
                                  color: TerminalColors.yellow,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Manual QEMU options. Do not modify ISO or hard drive settings.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _advancedOptionsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Additional QEMU Arguments',
                              hintText: '-display sdl -soundhw ac97',
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
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colorScheme.error,
                                  width: 2,
                                ),
                              ),
                              errorText: _advancedError,
                            ),
                            onChanged: (value) {
                              _containsForbiddenOptions(value);
                            },
                          ),
                          if (_advancedError != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Symbols.error,
                                  color: colorScheme.error,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _advancedError!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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

  Widget _buildConfigOption({
    required String label,
    String? subtitle,
    required IconData icon,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCommandPreview(ColorScheme colorScheme, TextTheme textTheme) {
    final command = _generateQemuCommand();

    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.terminal, color: TerminalColors.green, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Command Preview',
                  style: textTheme.titleLarge?.copyWith(
                    color: TerminalColors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TerminalColors.green.withValues(alpha: 0.3),
                ),
              ),
              child: SelectableText(
                command,
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: TerminalColors.green,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Symbols.info,
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '\${ISO_PATH} and \${HDD_PATH} will be replaced automatically during testing',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saveConfiguration,
        icon: Icon(Symbols.save, size: 20),
        label: Text('Save Configuration'),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
*/
