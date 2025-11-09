import 'dart:io';
import 'dart:convert';
import '../misc/logger.dart';

class CrossPlatformQemuManager {
  Process? _currentProcess;
  String? customQemuPath;
  String _lastError = '';

  // Get the last error message
  String get lastError => _lastError;

  // Use custom path if provided, otherwise use default detection
  String get qemuExecutable {
    if (customQemuPath != null && customQemuPath!.isNotEmpty) {
      return customQemuPath!;
    }

    if (Platform.isWindows) {
      return 'qemu-system-x86_64.exe';
    } else if (Platform.isMacOS) {
      return 'qemu-system-x86_64';
    } else if (Platform.isLinux) {
      return 'qemu-system-x86_64';
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }
  }

  // Get available display options for current platform
  List<String> get availableDisplayOptions {
    List<String> options = [];

    if (Platform.isLinux) {
      options.addAll(['gtk', 'sdl', 'vnc', 'spice', 'curses', 'none']);
    } else if (Platform.isMacOS) {
      options.addAll(['cocoa', 'gtk', 'sdl', 'vnc', 'curses', 'none']);
    } else if (Platform.isWindows) {
      options.addAll(['gtk', 'sdl', 'vnc', 'spice', 'curses', 'none']);
    } else {
      options.addAll(['gtk', 'sdl', 'vnc', 'none']);
    }

    return options;
  }

  // Get default display for platform
  String get defaultDisplay {
    if (Platform.isMacOS) {
      return 'cocoa';
    } else {
      return 'gtk';
    }
  }

  // Get platform-specific acceleration arguments
  List<String> get platformAcceleration {
    if (Platform.isLinux) {
      return ['-accel', 'kvm']; // KVM on Linux
    } else if (Platform.isMacOS) {
      return ['-accel', 'hvf']; // Hypervisor Framework on macOS
    } else if (Platform.isWindows) {
      return ['-accel', 'whpx']; // Windows Hypervisor Platform
    }
    return []; // Fallback to software emulation
  }

  // Get display arguments based on selection
  List<String> getDisplayArgs(String displayType) {
    switch (displayType.toLowerCase()) {
      case 'gtk':
        return ['-display', 'gtk'];
      case 'sdl':
        return ['-display', 'sdl'];
      case 'cocoa':
        return ['-display', 'cocoa'];
      case 'vnc':
        return ['-display', 'vnc=:1']; // VNC on display :1
      case 'spice':
        return ['-display', 'spice-app'];
      case 'curses':
        return ['-display', 'curses'];
      case 'none':
        return ['-display', 'none'];
      default:
        return ['-display', defaultDisplay];
    }
  }

  // Check if QEMU is installed and accessible
  Future<QemuInstallationStatus> checkQemuInstallation() async {
    try {
      String executable = qemuExecutable;
      AppLogger.debug('Checking QEMU at: $executable');

      ProcessResult result = await Process.run(executable, [
        '--version',
      ], runInShell: Platform.isWindows);

      if (result.exitCode == 0) {
        String version = result.stdout.toString().trim();
        String versionLine = version.split('\n').first;
        AppLogger.info('QEMU found: $versionLine');
        return QemuInstallationStatus.installed(versionLine);
      } else {
        String error = result.stderr.toString();
        AppLogger.warning('QEMU version check failed: $error');
        return QemuInstallationStatus.notWorking(error);
      }
    } catch (e) {
      AppLogger.error('Error checking QEMU: $e');
      if (e is ProcessException) {
        if (e.errorCode == 2 || e.message.contains('not found')) {
          return QemuInstallationStatus.notFound();
        }
      }
      return QemuInstallationStatus.error(e.toString());
    }
  }

  // Get installation instructions for the current platform
  String get installationInstructions {
    if (Platform.isWindows) {
      return '''Windows Installation:
1. Download QEMU from: https://qemu.weilnetz.de/w64/
2. Install the .exe file
3. Add QEMU to your PATH or specify full path
4. Common locations:
   • C:\\Program Files\\qemu\\qemu-system-x86_64.exe
   • C:\\qemu\\qemu-system-x86_64.exe''';
    } else if (Platform.isMacOS) {
      return '''macOS Installation:
1. Install Homebrew: https://brew.sh
2. Run: brew install qemu
3. Common locations:
   • /opt/homebrew/bin/qemu-system-x86_64 (Apple Silicon)
   • /usr/local/bin/qemu-system-x86_64 (Intel)''';
    } else if (Platform.isLinux) {
      return '''Linux Installation:
Ubuntu/Debian: sudo apt install qemu-system-x86
Fedora/RHEL: sudo dnf install qemu-system-x86
Arch: sudo pacman -S qemu-desktop
Common locations:
   • /usr/bin/qemu-system-x86_64
   • /usr/local/bin/qemu-system-x86_64''';
    }
    return 'Unsupported platform for installation instructions.';
  }

  // Start VM with comprehensive options and better error handling
  Future<bool> startVM({
    required String isoPath,
    String memoryMB = '1024',
    String cpuCores = '2',
    bool enableAcceleration = true,
    bool enableNetworking = false,
    String displayType = '',
    Map<String, String> customArgs = const {},
    String? vmName,
  }) async {
    _lastError = '';

    if (_currentProcess != null) {
      _lastError = 'VM already running! PID: ${_currentProcess!.pid}';
      AppLogger.warning(_lastError);
      return false;
    }

    // Validate inputs
    if (isoPath.trim().isEmpty) {
      _lastError = 'ISO path cannot be empty';
      AppLogger.warning(_lastError);
      return false;
    }

    // Check if ISO file exists
    File isoFile = File(isoPath);
    if (!await isoFile.exists()) {
      _lastError = 'ISO file not found: $isoPath';
      AppLogger.warning(_lastError);
      return false;
    }

    // Check ISO file size (should be > 0)
    try {
      int fileSize = await isoFile.length();
      if (fileSize == 0) {
        _lastError = 'ISO file is empty: $isoPath';
        AppLogger.warning(_lastError);
        return false;
      }
      AppLogger.info(
        'ISO file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );
    } catch (e) {
      _lastError = 'Cannot read ISO file: $e';
      AppLogger.error(_lastError);
      return false;
    }

    // Validate QEMU executable
    String executable = qemuExecutable;
    AppLogger.debug('Using QEMU executable: $executable');

    // Check if it's just a command name or full path
    if (!executable.contains(Platform.pathSeparator)) {
      // It's a command name, check if it exists in PATH
      try {
        ProcessResult which = await Process.run(
          Platform.isWindows ? 'where' : 'which',
          [executable],
          runInShell: Platform.isWindows,
        );
        if (which.exitCode != 0) {
          _lastError = 'QEMU executable not found in PATH: $executable';
          AppLogger.error(_lastError);
          return false;
        } else {
          String foundPath = which.stdout.toString().trim().split('\n').first;
          AppLogger.info('QEMU found in PATH at: $foundPath');
        }
      } catch (e) {
        _lastError = 'Error checking QEMU in PATH: $e';
        AppLogger.error(_lastError);
        return false;
      }
    } else {
      // It's a full path, check if file exists
      if (!await File(executable).exists()) {
        _lastError = 'QEMU executable not found at path: $executable';
        AppLogger.error(_lastError);
        return false;
      }
    }

    // Validate memory format
    if (!RegExp(r'^\d+$').hasMatch(memoryMB)) {
      _lastError = 'Invalid memory format: $memoryMB (should be number only)';
      AppLogger.warning(_lastError);
      return false;
    }

    // Validate CPU cores
    if (!RegExp(r'^\d+$').hasMatch(cpuCores)) {
      _lastError =
          'Invalid CPU cores format: $cpuCores (should be number only)';
      AppLogger.warning(_lastError);
      return false;
    }

    // Build arguments list
    List<String> args = [];

    // Basic VM configuration
    args.addAll(['-cdrom', isoPath]);
    args.addAll(['-m', memoryMB]);
    args.addAll(['-smp', cpuCores]);
    args.addAll(['-boot', 'd']);

    // Add VM name
    String finalVmName = vmName?.isNotEmpty == true
        ? vmName!
        : 'BootVM_${DateTime.now().millisecondsSinceEpoch}';
    args.addAll(['-name', finalVmName]);

    // IMPORTANT: Enable QEMU monitor for proper shutdown
    args.addAll(['-monitor', 'stdio']); // This enables monitor on stdin/stdout

    // Add platform-specific acceleration if enabled
    if (enableAcceleration) {
      try {
        List<String> accelArgs = platformAcceleration;
        if (accelArgs.isNotEmpty) {
          args.addAll(accelArgs);
          AppLogger.info(
            'Hardware acceleration enabled: ${accelArgs.join(' ')}',
          );
        } else {
          AppLogger.info(
            'Hardware acceleration not available on this platform',
          );
        }
      } catch (e) {
        AppLogger.warning(
          'Hardware acceleration not available, using software emulation: $e',
        );
      }
    }

    // Add display arguments
    String finalDisplayType = displayType.isEmpty
        ? defaultDisplay
        : displayType;
    List<String> displayArgs = getDisplayArgs(finalDisplayType);
    args.addAll(displayArgs);
    AppLogger.debug(
      'Display type: $finalDisplayType (${displayArgs.join(' ')})',
    );

    // Add networking if requested
    if (enableNetworking) {
      args.addAll([
        '-device',
        'virtio-net-pci,netdev=net0',
        '-netdev',
        'user,id=net0',
      ]);
      AppLogger.info('Networking enabled with user-mode networking');
    }

    // Add some useful defaults for OS development
    args.addAll([
      '-rtc', 'base=utc,clock=host', // Real-time clock
      '-no-reboot', // Don't automatically reboot on triple fault
    ]);

    // Add custom arguments (these can override defaults)
    customArgs.forEach((key, value) {
      if (value.isEmpty) {
        args.add(key); // Flag without value
      } else {
        args.addAll([key, value]);
      }
    });

    try {
      AppLogger.info('Starting QEMU VM...');
      AppLogger.debug('Executable: $executable');
      AppLogger.debug('Arguments: ${args.join(' ')}');
      AppLogger.debug('Full command: $executable ${args.join(' ')}');

      // Start the process
      _currentProcess = await Process.start(
        executable,
        args,
        runInShell: Platform.isWindows,
      );

      // Set up stream handling

      // Handle stdout (this includes monitor output)
      _currentProcess!.stdout
          .transform(utf8.decoder)
          .listen(
            (data) {
              String cleanData = data.trim();
              if (cleanData.isNotEmpty) {
                // Filter out QEMU monitor prompt
                if (!cleanData.startsWith('(qemu)') && cleanData != 'QEMU') {
                  AppLogger.debug('QEMU stdout: $cleanData');
                }
              }
            },
            onError: (error) {
              AppLogger.warning('QEMU stdout error: $error');
            },
            onDone: () {
              AppLogger.debug('QEMU stdout stream closed');
            },
          );

      // Handle stderr
      _currentProcess!.stderr
          .transform(utf8.decoder)
          .listen(
            (data) {
              String cleanData = data.trim();
              if (cleanData.isNotEmpty) {
                AppLogger.debug('QEMU stderr: $cleanData');
                // Capture error for user feedback
                if (_lastError.isEmpty && cleanData.contains('error')) {
                  _lastError = cleanData;
                }
              }
            },
            onError: (error) {
              AppLogger.warning('QEMU stderr error: $error');
            },
            onDone: () {
              AppLogger.debug('QEMU stderr stream closed');
            },
          );

      // Handle process exit
      _currentProcess!.exitCode.then((exitCode) {
        AppLogger.info('QEMU process exited with code: $exitCode');
        if (exitCode == 0) {
          AppLogger.info('VM shut down normally');
        } else {
          AppLogger.warning('VM exited with error code: $exitCode');
          if (_lastError.isEmpty) {
            _lastError = 'VM exited with error code: $exitCode';
          }
        }
        _currentProcess = null;
      });

      // Give QEMU time to start and potentially fail
      await Future.delayed(Duration(milliseconds: 1000));

      // Check if process is still running
      try {
        // Try to get the PID - if this throws, process has died
        int pid = _currentProcess!.pid;
        AppLogger.info('QEMU VM started successfully with PID: $pid');
        return true;
      } catch (e) {
        AppLogger.error('QEMU process died immediately: $e');
        if (_lastError.isEmpty) {
          _lastError = 'QEMU process crashed on startup: $e';
        }
        _currentProcess = null;
        return false;
      }
    } catch (e) {
      _lastError = 'Failed to start QEMU process: $e';
      AppLogger.error(_lastError);
      _currentProcess = null;
      return false;
    }
  }

  // Stop the VM gracefully - FIXED VERSION
  Future<bool> stopVM() async {
    if (_currentProcess == null) {
      AppLogger.info('No VM is currently running');
      return false;
    }

    try {
      int pid = _currentProcess!.pid;
      AppLogger.info('Stopping QEMU VM (PID: $pid)...');

      // Method 1: Send 'quit' command to QEMU monitor
      try {
        AppLogger.debug('Sending quit command to QEMU monitor...');
        _currentProcess!.stdin.writeln('quit');
        await _currentProcess!.stdin.flush();
        AppLogger.debug('Quit command sent to QEMU monitor');

        // Wait for graceful shutdown
        AppLogger.debug('Waiting for VM to shut down gracefully...');
        int? exitCode = await _currentProcess!.exitCode.timeout(
          Duration(seconds: 5),
          onTimeout: () => -1,
        );

        AppLogger.info('VM shut down gracefully with exit code: $exitCode');
        _currentProcess = null;
        return true;
      } catch (e) {
        AppLogger.warning('Monitor quit command failed: $e');
      }

      // Method 2: Try system_powerdown command
      if (_currentProcess != null) {
        try {
          AppLogger.debug('Trying system_powerdown command...');
          _currentProcess!.stdin.writeln('system_powerdown');
          await _currentProcess!.stdin.flush();

          // Wait for shutdown
          int? exitCode = await _currentProcess!.exitCode.timeout(
            Duration(seconds: 5),
            onTimeout: () => -1,
          );

          AppLogger.info('VM powered down with exit code: $exitCode');
          _currentProcess = null;
          return true;
        } catch (e) {
          AppLogger.warning('Powerdown command failed: $e');
        }
      }

      // Method 3: Close stdin to signal shutdown
      if (_currentProcess != null) {
        try {
          AppLogger.debug('Closing stdin to signal shutdown...');
          await _currentProcess!.stdin.close();

          // Wait for shutdown
          int? exitCode = await _currentProcess!.exitCode.timeout(
            Duration(seconds: 3),
            onTimeout: () => -1,
          );

          AppLogger.info(
            'VM shut down after stdin close with exit code: $exitCode',
          );
          _currentProcess = null;
          return true;
        } catch (e) {
          AppLogger.warning('Stdin close failed: $e');
        }
      }

      // Method 4: Send SIGTERM
      if (_currentProcess != null) {
        try {
          AppLogger.info('VM still running, sending SIGTERM...');
          bool killed = _currentProcess!.kill(ProcessSignal.sigterm);
          AppLogger.debug('SIGTERM sent: $killed');

          if (killed) {
            // Wait for process to exit
            int? exitCode = await _currentProcess!.exitCode.timeout(
              Duration(seconds: 3),
              onTimeout: () => -1,
            );

            AppLogger.info('VM terminated with SIGTERM, exit code: $exitCode');
            _currentProcess = null;
            return true;
          }
        } catch (e) {
          AppLogger.warning('SIGTERM failed: $e');
        }
      }

      // Method 5: Force kill with SIGKILL (last resort)
      if (_currentProcess != null) {
        try {
          AppLogger.warning('VM still running, using SIGKILL (force kill)...');
          bool killed = _currentProcess!.kill(ProcessSignal.sigkill);
          AppLogger.debug('SIGKILL sent: $killed');

          if (killed) {
            // Wait for process to be killed
            try {
              int exitCode = await _currentProcess!.exitCode.timeout(
                Duration(seconds: 2),
              );
              AppLogger.info('VM force killed, exit code: $exitCode');
            } catch (e) {
              AppLogger.warning(
                'Force kill timeout, but process should be dead: $e',
              );
            }
          }
        } catch (e) {
          AppLogger.warning('SIGKILL failed: $e');
        }
      }

      // Clean up regardless
      _currentProcess = null;
      AppLogger.info('VM stop procedure completed');
      return true;
    } catch (e) {
      AppLogger.error('Error during VM stop procedure: $e');
      _currentProcess = null;
      return false;
    }
  }

  // Alternative stop method for troubleshooting
  Future<bool> forceStopVM() async {
    if (_currentProcess == null) {
      AppLogger.info('No VM is currently running');
      return false;
    }

    try {
      int pid = _currentProcess!.pid;
      AppLogger.info('Force stopping QEMU VM (PID: $pid)...');

      // Skip graceful shutdown and go straight to SIGKILL
      bool killed = _currentProcess!.kill(ProcessSignal.sigkill);
      AppLogger.debug('SIGKILL sent: $killed');

      if (killed) {
        try {
          int exitCode = await _currentProcess!.exitCode.timeout(
            Duration(seconds: 5),
          );
          AppLogger.info('VM force stopped with exit code: $exitCode');
          _currentProcess = null;
          return true;
        } catch (e) {
          AppLogger.warning('Timeout waiting for force stop: $e');
          _currentProcess = null;
          return true; // Assume it worked
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error force stopping VM: $e');
      _currentProcess = null;
      return false;
    }
  }

  // Check if VM is currently running
  bool get isRunning => _currentProcess != null;

  // Get VM process ID if running
  int? get vmPid => _currentProcess?.pid;
}

// Helper class for QEMU installation status
class QemuInstallationStatus {
  final bool isInstalled;
  final String message;
  final String? version;

  const QemuInstallationStatus._(this.isInstalled, this.message, this.version);

  factory QemuInstallationStatus.installed(String version) {
    return QemuInstallationStatus._(
      true,
      'QEMU is installed and working',
      version,
    );
  }

  factory QemuInstallationStatus.notFound() {
    return QemuInstallationStatus._(false, 'QEMU executable not found', null);
  }

  factory QemuInstallationStatus.notWorking(String error) {
    return QemuInstallationStatus._(
      false,
      'QEMU found but not working: $error',
      null,
    );
  }

  factory QemuInstallationStatus.error(String error) {
    return QemuInstallationStatus._(false, 'Error checking QEMU: $error', null);
  }
}
