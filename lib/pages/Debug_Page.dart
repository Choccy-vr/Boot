import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/services/notifications/notifications.dart';
import '/services/users/User.dart';
import '/services/Projects/project_service.dart';
import '/services/hackatime/hackatime_service.dart';
import '/theme/terminal_theme.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  String _lastAction = 'No action yet';
  bool _isLoading = false;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _projectIdController = TextEditingController();

  String? _selectedUserId;
  int? _selectedProjectId;

  @override
  void dispose() {
    _userIdController.dispose();
    _projectIdController.dispose();
    super.dispose();
  }

  void _setStatus(String status) {
    setState(() {
      _lastAction = status;
    });
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Symbols.bug_report, color: TerminalColors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              'Debug Console',
              style: textTheme.titleLarge?.copyWith(
                color: TerminalColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Display
            Container(
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
                      Icon(
                        Symbols.terminal,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Last Action:',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastAction,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(color: colorScheme.primary),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Entity Editor Section
            _buildEntityEditor(colorScheme, textTheme),
            const SizedBox(height: 24),

            // Notification Tests
            _buildSection(
              'Notification System',
              Symbols.notifications,
              colorScheme,
              textTheme,
              [
                _buildTestButton(
                  'Error (Transient)',
                  Symbols.error,
                  TerminalColors.red,
                  () {
                    GlobalNotificationService.instance.showError(
                      'Test transient error notification',
                    );
                    _setStatus('Showed transient error notification');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Error (Persistent)',
                  Symbols.error,
                  TerminalColors.red,
                  () {
                    GlobalNotificationService.instance.showError(
                      'Test persistent error - stays in history',
                      persistent: true,
                    );
                    _setStatus('Showed persistent error notification');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Warning',
                  Symbols.warning,
                  TerminalColors.yellow,
                  () {
                    GlobalNotificationService.instance.showWarning(
                      'Test warning notification',
                    );
                    _setStatus('Showed warning notification');
                  },
                  colorScheme,
                ),
                _buildTestButton('Info', Symbols.info, colorScheme.primary, () {
                  GlobalNotificationService.instance.showInfo(
                    'Test info notification',
                  );
                  _setStatus('Showed info notification');
                }, colorScheme),
                _buildTestButton(
                  'Success',
                  Symbols.check_circle,
                  TerminalColors.green,
                  () {
                    GlobalNotificationService.instance.showSuccess(
                      'Test success notification',
                    );
                    _setStatus('Showed success notification');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Promo with Action',
                  Symbols.campaign,
                  TerminalColors.magenta,
                  () {
                    GlobalNotificationService.instance.showPromo(
                      'Test promotional notification with action button',
                      actionLabel: 'Click Me',
                      onActionTap: () {
                        GlobalNotificationService.instance.showSuccess(
                          'Promo action executed!',
                        );
                      },
                    );
                    _setStatus('Showed promo notification with action');
                  },
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // User Service Tests
            _buildSection(
              'User Service',
              Symbols.person,
              colorScheme,
              textTheme,
              [
                _buildTestButton(
                  'Get Current User',
                  Symbols.account_circle,
                  colorScheme.primary,
                  () {
                    final user = UserService.currentUser;
                    if (user != null) {
                      _setStatus(
                        'User: ${user.username} (ID: ${user.id})\n'
                        'Email: ${user.email}\n'
                        'Coins: ${user.bootCoins}\n'
                        'Slack ID: ${user.slackUserId}',
                      );
                    } else {
                      _setStatus('No user logged in');
                    }
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Update User',
                  Symbols.refresh,
                  colorScheme.secondary,
                  () async {
                    _setLoading(true);
                    try {
                      await UserService.updateCurrentUser();
                      _setStatus('User updated successfully');
                    } catch (e) {
                      _setStatus('Error updating user: $e');
                    }
                    _setLoading(false);
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Test Hackatime Ban Check',
                  Symbols.block,
                  TerminalColors.red,
                  () async {
                    final user = UserService.currentUser;
                    if (user?.slackUserId != null &&
                        user!.slackUserId.isNotEmpty) {
                      _setLoading(true);
                      try {
                        final isBanned =
                            await HackatimeService.isHackatimeBanned(
                              slackUserId: user.slackUserId,
                            );
                        _setStatus(
                          'Hackatime ban status: ${isBanned ? "BANNED" : "OK"}',
                        );
                      } catch (e) {
                        _setStatus('Error checking ban status: $e');
                      }
                      _setLoading(false);
                    } else {
                      _setStatus('No Slack user ID available');
                    }
                  },
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Project Service Tests
            _buildSection(
              'Project Service',
              Symbols.construction,
              colorScheme,
              textTheme,
              [
                _buildTestButton(
                  'Get My Projects',
                  Symbols.list,
                  colorScheme.primary,
                  () async {
                    final user = UserService.currentUser;
                    if (user != null) {
                      _setLoading(true);
                      try {
                        final projects = await ProjectService.getProjects(
                          user.id,
                        );
                        _setStatus(
                          'Found ${projects.length} projects:\n' +
                              projects
                                  .map((p) => '- ${p.title}')
                                  .join('\n'),
                        );
                      } catch (e) {
                        _setStatus('Error fetching projects: $e');
                      }
                      _setLoading(false);
                    } else {
                      _setStatus('No user logged in');
                    }
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Get All Projects',
                  Symbols.public,
                  colorScheme.secondary,
                  () async {
                    _setLoading(true);
                    try {
                      final projects = await ProjectService.getAllProjects();
                      _setStatus(
                        'Found ${projects.length} total projects in database',
                      );
                    } catch (e) {
                      _setStatus('Error fetching all projects: $e');
                    }
                    _setLoading(false);
                  },
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Navigation Tests
            _buildSection(
              'Navigation',
              Symbols.navigation,
              colorScheme,
              textTheme,
              [
                _buildTestButton(
                  'Test Home Route',
                  Symbols.home,
                  colorScheme.primary,
                  () {
                    Navigator.pushNamed(context, '/dashboard');
                    _setStatus('Navigated to /dashboard');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Test Projects Route',
                  Symbols.construction,
                  colorScheme.secondary,
                  () {
                    Navigator.pushNamed(context, '/projects');
                    _setStatus('Navigated to /projects');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Test Explore Route',
                  Symbols.explore,
                  TerminalColors.magenta,
                  () {
                    Navigator.pushNamed(context, '/explore');
                    _setStatus('Navigated to /explore');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Test Invalid Route',
                  Symbols.error_outline,
                  TerminalColors.red,
                  () {
                    Navigator.pushNamed(context, '/invalid-route-test');
                    _setStatus('Navigated to invalid route (should show 404)');
                  },
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Theme & UI Tests
            _buildSection(
              'Theme & UI',
              Symbols.palette,
              colorScheme,
              textTheme,
              [
                _buildTestButton(
                  'Show All Colors',
                  Symbols.color_lens,
                  colorScheme.primary,
                  () {
                    _setStatus(
                      'Primary: ${colorScheme.primary}\n'
                      'Secondary: ${colorScheme.secondary}\n'
                      'Error: ${colorScheme.error}\n'
                      'Surface: ${colorScheme.surface}\n'
                      'Terminal Red: ${TerminalColors.red}\n'
                      'Terminal Green: ${TerminalColors.green}',
                    );
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Test Dialog',
                  Symbols.chat_bubble,
                  colorScheme.secondary,
                  () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Test Dialog'),
                        content: Text(
                          'This is a test dialog from debug console',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close'),
                          ),
                        ],
                      ),
                    );
                    _setStatus('Showed test dialog');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Test Bottom Sheet',
                  Symbols.vertical_align_bottom,
                  TerminalColors.cyan,
                  () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Container(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Test Bottom Sheet',
                              style: textTheme.titleLarge,
                            ),
                            SizedBox(height: 16),
                            Text('This is a test bottom sheet'),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    );
                    _setStatus('Showed test bottom sheet');
                  },
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stress Tests
            _buildSection(
              'Stress Tests',
              Symbols.speed,
              colorScheme,
              textTheme,
              [
                _buildTestButton(
                  'Spam Notifications (10)',
                  Symbols.notification_multiple,
                  TerminalColors.yellow,
                  () {
                    for (int i = 1; i <= 10; i++) {
                      Future.delayed(Duration(milliseconds: i * 200), () {
                        GlobalNotificationService.instance.showInfo(
                          'Spam notification #$i',
                        );
                      });
                    }
                    _setStatus('Spamming 10 notifications...');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Mixed Notification Spam',
                  Symbols.shuffle,
                  TerminalColors.magenta,
                  () {
                    final types = ['error', 'warning', 'info', 'success'];
                    for (int i = 0; i < 8; i++) {
                      Future.delayed(Duration(milliseconds: i * 300), () {
                        final type = types[i % types.length];
                        switch (type) {
                          case 'error':
                            GlobalNotificationService.instance.showError(
                              'Error #$i',
                            );
                            break;
                          case 'warning':
                            GlobalNotificationService.instance.showWarning(
                              'Warning #$i',
                            );
                            break;
                          case 'info':
                            GlobalNotificationService.instance.showInfo(
                              'Info #$i',
                            );
                            break;
                          case 'success':
                            GlobalNotificationService.instance.showSuccess(
                              'Success #$i',
                            );
                            break;
                        }
                      });
                    }
                    _setStatus('Spamming mixed notifications...');
                  },
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityEditor(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TerminalColors.red, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.admin_panel_settings,
                color: TerminalColors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Entity Editor - ALL POWERFUL MODE',
                  style: textTheme.titleLarge?.copyWith(
                    color: TerminalColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ WARNING: Direct database manipulation - use with caution!',
            style: textTheme.bodySmall?.copyWith(
              color: TerminalColors.yellow,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          // User Editor
          Text(
            'User Editor',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userIdController,
                  decoration: InputDecoration(
                    labelText: 'User UUID',
                    hintText: '7f18c57b-ca6f-4812-aac7-a2fb6cc10362',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.person),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value.isNotEmpty ? value : null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_userIdController.text.isNotEmpty) {
                    setState(() {
                      _selectedUserId = _userIdController.text;
                    });
                    _setStatus('Selected user: $_selectedUserId');
                  }
                },
                child: Text('Load'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedUserId != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  'Get User Info',
                  Symbols.info,
                  colorScheme.primary,
                  () async {
                    _setLoading(true);
                    try {
                      final user = await UserService.getUserById(
                        _selectedUserId!,
                      );
                      if (user != null) {
                        _setStatus(
                          'User: ${user.username}\n'
                          'Email: ${user.email}\n'
                          'ID: ${user.id}\n'
                          'Coins: ${user.bootCoins}\n'
                          'Slack ID: ${user.slackUserId}\n'
                          'Profile: ${user.profilePicture}',
                        );
                      } else {
                        _setStatus('User not found');
                      }
                    } catch (e) {
                      _setStatus('Error: $e');
                    }
                    _setLoading(false);
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Ban from Hackatime',
                  Symbols.block,
                  TerminalColors.red,
                  () async {
                    final user = await UserService.getUserById(
                      _selectedUserId!,
                    );
                    if (user?.slackUserId != null && user!.slackUserId.isNotEmpty) {
                      _setStatus(
                        'Check Hackatime ban status for user ${user.slackUserId}\n'
                        '(Note: You cannot actually ban users from here - this is read-only)',
                      );
                    } else {
                      _setStatus('User has no Slack ID');
                    }
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Get User Projects',
                  Symbols.construction,
                  colorScheme.secondary,
                  () async {
                    _setLoading(true);
                    try {
                      final projects = await ProjectService.getProjects(
                        _selectedUserId!,
                      );
                      _setStatus(
                        'User has ${projects.length} projects:\n' +
                            projects
                                .map((p) => '- ${p.title}')
                                .join('\n'),
                      );
                    } catch (e) {
                      _setStatus('Error: $e');
                    }
                    _setLoading(false);
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Get Hackatime Stats',
                  Symbols.query_stats,
                  TerminalColors.cyan,
                  () async {
                    _setLoading(true);
                    try {
                      final user = await UserService.getUserById(
                        _selectedUserId!,
                      );
                      if (user?.slackUserId != null &&
                          user!.slackUserId.isNotEmpty) {
                        final projects =
                            await HackatimeService.fetchHackatimeProjects(
                              slackUserId: user.slackUserId,
                            );
                        _setStatus(
                          'Hackatime projects: ${projects.length}\n' +
                              projects
                                  .take(5)
                                  .map((p) => '- ${p.name}: ${p.text}')
                                  .join('\n'),
                        );
                      } else {
                        _setStatus('User has no Slack user ID');
                      }
                    } catch (e) {
                      _setStatus('Error: $e');
                    }
                    _setLoading(false);
                  },
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Project Editor
          Text(
            'Project Editor',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _projectIdController,
                  decoration: InputDecoration(
                    labelText: 'Project ID',
                    hintText: 'Enter numeric project ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.construction),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _selectedProjectId = int.tryParse(value);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final id = int.tryParse(_projectIdController.text);
                  if (id != null) {
                    setState(() {
                      _selectedProjectId = id;
                    });
                    _setStatus('Selected project ID: $id');
                  }
                },
                child: Text('Load'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedProjectId != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  'Get Project Info',
                  Symbols.info,
                  colorScheme.primary,
                  () async {
                    _setLoading(true);
                    try {
                      final project = await ProjectService.getProjectById(
                        _selectedProjectId!,
                      );
                      if (project != null) {
                        _setStatus(
                          'Title: ${project.title}\n'
                          'Description: ${project.description}\n'
                          'Shipped: ${project.shipped}\n'
                          'Level: ${project.level}\n'
                          'Created: ${project.createdAt}\n'
                          'Owner: ${project.owner}',
                        );
                      } else {
                        _setStatus('Project not found');
                      }
                    } catch (e) {
                      _setStatus('Error: $e');
                    }
                    _setLoading(false);
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Get Project Devlogs',
                  Symbols.article,
                  TerminalColors.magenta,
                  () {
                    _setStatus('Devlog fetching not implemented yet');
                  },
                  colorScheme,
                ),
                _buildTestButton(
                  'Navigate to Project',
                  Symbols.open_in_new,
                  colorScheme.secondary,
                  () {
                    Navigator.pushNamed(
                      context,
                      '/projects/$_selectedProjectId',
                    );
                    _setStatus('Navigated to project $_selectedProjectId');
                  },
                  colorScheme,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    ColorScheme colorScheme,
    TextTheme textTheme,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    ColorScheme colorScheme,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
    );
  }
}
