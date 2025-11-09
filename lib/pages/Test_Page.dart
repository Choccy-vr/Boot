import 'package:flutter/material.dart';
import 'dart:io';
import '../services/vm/qemu_manager.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final CrossPlatformQemuManager _qemu = CrossPlatformQemuManager();

  // Controllers for text fields
  final TextEditingController _qemuPathController = TextEditingController();
  final TextEditingController _isoPathController = TextEditingController();
  final TextEditingController _memoryController = TextEditingController(
    text: '1024',
  );
  final TextEditingController _cpuController = TextEditingController(text: '2');
  final TextEditingController _customArgsController = TextEditingController();

  // State variables
  bool _enableAcceleration = true;
  bool _enableNetworking = false;
  bool _isLoading = false;
  String _status = 'Ready';
  String _selectedDisplay = '';
  QemuInstallationStatus? _installStatus;

  @override
  void initState() {
    super.initState();
    _selectedDisplay = _qemu.defaultDisplay;
    _checkQemuInstallation();
    // Set default paths
    _isoPathController.text = _getDefaultISOPath();
    _qemuPathController.text = _getDefaultQemuPath();
  }

  String _getDefaultISOPath() {
    if (Platform.isMacOS) {
      return '/Users/Choccy-vr/Downloads/test-os.iso';
    } else if (Platform.isWindows) {
      return 'C:\\Users\\Choccy-vr\\Downloads\\test-os.iso';
    } else {
      return '/home/Choccy-vr/Downloads/test-os.iso';
    }
  }

  String _getDefaultQemuPath() {
    if (Platform.isMacOS) {
      return '/opt/homebrew/bin/qemu-system-x86_64';
    } else if (Platform.isWindows) {
      return 'C:\\Program Files\\qemu\\qemu-system-x86_64.exe';
    } else {
      return '/usr/bin/qemu-system-x86_64';
    }
  }

  Future<void> _checkQemuInstallation() async {
    setState(() => _isLoading = true);

    // Update QEMU manager with custom path
    _qemu.customQemuPath = _qemuPathController.text.trim().isNotEmpty
        ? _qemuPathController.text.trim()
        : null;

    final status = await _qemu.checkQemuInstallation();
    setState(() {
      _installStatus = status;
      _status = status.isInstalled ? 'Ready' : 'QEMU not found';
      _isLoading = false;
    });
  }

  Future<void> _forceStopVM() async {
    setState(() => _status = 'Force stopping VM...');
    bool success = await _qemu.forceStopVM();
    setState(() {
      _status = success ? 'VM Force Stopped' : 'Ready';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Boot Terminal'),
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(colorScheme, textTheme),
            const SizedBox(height: 16),

            // Configuration Card
            _buildConfigurationCard(colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _qemu.isRunning ? Icons.play_circle : Icons.computer,
                  color: _qemu.isRunning
                      ? colorScheme.primary
                      : colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'QEMU Virtual Machine',
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Platform: ${Platform.operatingSystem}',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            Text(
              'Status: $_status',
              style: TextStyle(
                color: _qemu.isRunning
                    ? colorScheme.primary
                    : _installStatus?.isInstalled == false
                    ? colorScheme.error
                    : colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_installStatus?.version != null)
              Text(
                'QEMU: ${_installStatus!.version}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            if (_qemu.lastError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: colorScheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last Error: ${_qemu.lastError}',
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontSize: 12,
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

  Widget _buildConfigurationCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VM Configuration',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // QEMU Path
            _buildPathField(
              controller: _qemuPathController,
              label: 'QEMU Executable Path',
              hint: 'Path to qemu-system-x86_64',
              icon: Icons.settings_applications,
              onBrowse: _browseForQemu,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),

            // ISO Path
            _buildPathField(
              controller: _isoPathController,
              label: 'ISO File Path',
              hint: 'Path to your .iso file',
              icon: Icons.folder,
              onBrowse: _browseForISO,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),

            // Memory and CPU
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    _memoryController,
                    'Memory (MB)',
                    Icons.memory,
                    colorScheme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                    _cpuController,
                    'CPU Cores',
                    Icons.developer_board,
                    colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Display Type Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedDisplay,
              decoration: InputDecoration(
                labelText: 'Display Type',
                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: Icon(
                  Icons.monitor,
                  color: colorScheme.onSurfaceVariant,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              dropdownColor: colorScheme.surfaceContainerHigh,
              style: TextStyle(color: colorScheme.onSurface),
              items: _qemu.availableDisplayOptions.map((String display) {
                return DropdownMenuItem<String>(
                  value: display,
                  child: Text(display.toUpperCase()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedDisplay = newValue ?? _qemu.defaultDisplay;
                });
              },
            ),
            const SizedBox(height: 16),

            // Switches
            SwitchListTile(
              title: Text(
                'Hardware Acceleration',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                _getAccelerationType(),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              value: _enableAcceleration,
              onChanged: (value) => setState(() => _enableAcceleration = value),
              activeThumbColor: colorScheme.primary,
            ),

            SwitchListTile(
              title: Text(
                'Enable Networking',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'Allow VM to access network',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              value: _enableNetworking,
              onChanged: (value) => setState(() => _enableNetworking = value),
              activeThumbColor: colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // Custom Arguments
            TextField(
              controller: _customArgsController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Custom QEMU Arguments (Optional)',
                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                hintText: '-soundhw ac97 -usb',
                hintStyle: TextStyle(color: colorScheme.outline),
                prefixIcon: Icon(
                  Icons.terminal,
                  color: colorScheme.onSurfaceVariant,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(colorScheme),
            const SizedBox(height: 16),

            // Command Preview
            _buildCommandPreview(colorScheme),
            const SizedBox(height: 16),

            // Installation Help
            if (_installStatus?.isInstalled == false)
              _buildInstallationHelp(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPathField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onBrowse,
    required ColorScheme colorScheme,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.outline),
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        suffixIcon: IconButton(
          icon: Icon(Icons.folder_open, color: colorScheme.onSurfaceVariant),
          onPressed: onBrowse,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String label,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading || _qemu.isRunning ? null : _startVM,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
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
                : const Icon(Icons.play_arrow),
            label: const Text('Start VM'),
          ),
        ),

        // In your _buildActionButtons method, replace the stop button section:
        if (_qemu.isRunning) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _stopVM,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
              icon: const Icon(Icons.stop),
              label: const Text('Stop VM'),
            ),
          ),
          const SizedBox(width: 8),
          // Add force stop button
          IconButton(
            onPressed: _forceStopVM,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.error,
              backgroundColor: colorScheme.errorContainer,
            ),
            icon: const Icon(Icons.power_off),
            tooltip: 'Force Stop VM',
          ),
        ],
      ],
    );
  }

  Widget _buildCommandPreview(ColorScheme colorScheme) {
    String command = _buildCommandString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Command Preview:',
              style: TextStyle(
                color: colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _copyToClipboard(command),
              icon: Icon(Icons.copy, size: 16, color: colorScheme.primary),
              label: Text('Copy', style: TextStyle(color: colorScheme.primary)),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorScheme.outline),
          ),
          child: SelectableText(
            command,
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstallationHelp(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'QEMU Not Found',
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _qemu.installationInstructions,
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _checkQemuInstallation,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Check Again'),
          ),
        ],
      ),
    );
  }

  String _getAccelerationType() {
    if (Platform.isLinux) return 'KVM';
    if (Platform.isMacOS) return 'HVF';
    if (Platform.isWindows) return 'WHPX';
    return 'Software only';
  }

  String _buildCommandString() {
    List<String> args = [
      _qemuPathController.text.trim().isNotEmpty
          ? _qemuPathController.text.trim()
          : _qemu.qemuExecutable,
    ];
    args.addAll(['-cdrom', _isoPathController.text]);
    args.addAll(['-m', _memoryController.text]);
    args.addAll(['-smp', _cpuController.text]);
    args.addAll(['-boot', 'd']);

    if (_enableAcceleration) {
      args.addAll(_qemu.platformAcceleration);
    }

    args.addAll(_qemu.getDisplayArgs(_selectedDisplay));

    if (_enableNetworking) {
      args.addAll([
        '-device',
        'virtio-net-pci,netdev=net0',
        '-netdev',
        'user,id=net0',
      ]);
    }

    if (_customArgsController.text.trim().isNotEmpty) {
      args.addAll(_customArgsController.text.trim().split(' '));
    }

    return args.join(' ');
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Command copied to clipboard!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _browseForQemu() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select QEMU Executable',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _qemuPathController.text = result.files.single.path!;
        });
        _checkQemuInstallation();
      }
    } catch (e) {
      _showError('Error selecting QEMU executable: $e');
    }
  }

  Future<void> _browseForISO() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['iso'],
        dialogTitle: 'Select ISO File',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isoPathController.text = result.files.single.path!;
        });
      }
    } catch (e) {
      _showError('Error selecting ISO file: $e');
    }
  }

  Future<void> _startVM() async {
    if (_qemuPathController.text.trim().isEmpty) {
      _showError('Please enter QEMU executable path');
      return;
    }

    if (_isoPathController.text.trim().isEmpty) {
      _showError('Please enter an ISO file path');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Starting VM...';
    });

    // Update QEMU manager with custom path
    _qemu.customQemuPath = _qemuPathController.text.trim();

    try {
      Map<String, String> customArgs = {};
      if (_customArgsController.text.trim().isNotEmpty) {
        List<String> argsList = _customArgsController.text.trim().split(' ');
        for (int i = 0; i < argsList.length - 1; i += 2) {
          if (argsList[i].startsWith('-') && i + 1 < argsList.length) {
            customArgs[argsList[i]] = argsList[i + 1];
          }
        }
      }

      bool success = await _qemu.startVM(
        isoPath: _isoPathController.text.trim(),
        memoryMB: _memoryController.text.trim(),
        cpuCores: _cpuController.text.trim(),
        enableAcceleration: _enableAcceleration,
        enableNetworking: _enableNetworking,
        displayType: _selectedDisplay,
        customArgs: customArgs,
        vmName: 'BootVM_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _isLoading = false;
        _status = success ? 'VM Running' : 'Failed to start VM';
      });

      if (success) {
        _showSuccess('VM launched successfully! PID: ${_qemu.vmPid}');
      } else {
        _showError('Failed to start VM. Error: ${_qemu.lastError}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
      _showError('Error: $e');
    }
  }

  Future<void> _stopVM() async {
    setState(() => _status = 'Stopping VM...');
    bool success = await _qemu.stopVM();
    setState(() {
      _status = success ? 'VM Stopped' : 'Ready';
    });
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        title: Text(
          'Error',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
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

  void _showSuccess(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text(
          'Success! 🚀',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _qemuPathController.dispose();
    _isoPathController.dispose();
    _memoryController.dispose();
    _cpuController.dispose();
    _customArgsController.dispose();
    if (_qemu.isRunning) {
      _qemu.stopVM();
    }
    super.dispose();
  }
}
