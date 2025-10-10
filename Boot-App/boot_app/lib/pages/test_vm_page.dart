import 'package:boot_app/services/vm/cloud_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rfb/flutter_rfb.dart';

class TestVmPage extends StatefulWidget {
  const TestVmPage({super.key});

  @override
  State<TestVmPage> createState() => _TestVmPageState();
}

class _TestVmPageState extends State<TestVmPage> {
  String? vmIp;
  bool isLoading = false;
  bool showVnc = false;

  Future<void> _createVM() async {
    setState(() {
      isLoading = true;
      vmIp = null;
      showVnc = false;
    });

    CloudVmService.createVM()
        .then((data) {
          print(data);
          setState(() {
            vmIp =
                data['ip']; // Assuming the function returns {'ip': 'x.x.x.x'}
            showVnc = vmIp != null;
          });
        })
        .catchError((error) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating VM: $error')));
        });

    setState(() {
      isLoading = false;
      if (vmIp != null) {
        showVnc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Test VM')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VM Information',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'IP: ${vmIp ?? 'Not assigned'}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: showVnc && vmIp != null
                ? _buildVncView()
                : Center(
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _createVM,
                            child: const Text('Create VM'),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVncView() {
    return RemoteFrameBufferWidget(
      hostName: vmIp!,
      port: 5900,
      password: '',
      onError: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('VNC Error: $error')));
      },
    );
  }
}
