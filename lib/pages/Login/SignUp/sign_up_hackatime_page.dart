import 'package:flutter/material.dart';
import '../../../services/navigation/navigation_service.dart';
import '/services/users/signup/sign_up_service.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:boot_app/services/users/User.dart';

class SignupHackatimePage extends StatefulWidget {
  const SignupHackatimePage({super.key});

  @override
  State<SignupHackatimePage> createState() => _SignupHackatimePageState();
}

class _SignupHackatimePageState extends State<SignupHackatimePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _apiController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(colorScheme, textTheme),
              _buildAboutSection(colorScheme, textTheme),
              _buildAPIFields(colorScheme, textTheme),
              _buildFinishButton(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                'boot ~ ${UserService.currentUser?.username}@ysws',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'One last step!',
            style: textTheme.displayLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Time to configure hackatime',
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: colorScheme.surfaceContainer,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Symbols.schedule, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'About Hackatime',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Hackatime is a powerful time tracking tool that monitors your coding activity across different projects and programming languages. It provides detailed insights into your development workflow and helps you understand where you spend your time.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 12),
              Text(
                'Used by developers and Hack Club YSWS (You Ship, We Ship) events to track project time.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAPIFields(ColorScheme colorScheme, TextTheme textTheme) {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                TextField(
                  controller: _apiController,
                  enabled: !_isLoading,
                  maxLength: 36,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'Enter your Hackatime API Key',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 64,
                  onSubmitted: (_) => _handleSignUp(),
                  decoration: InputDecoration(
                    labelText: 'Hackatime Username',
                    hintText: 'Enter your Hackatime Username or User ID',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSignUp,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Finishing...',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Finish Sign Up',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    final username = _usernameController.text.trim();
    final apiKey = _apiController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your hackatime username or user id'),
        ),
      );
      return;
    }

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your hackatime API key')),
      );
      return;
    }

    // Validate API key format (UUID-like)
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRegex.hasMatch(apiKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API key must be a valid UUID format')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      SignupService.signUpUser.hackatimeUsername = username;
      SignupService.signUpUser.hackatimeApiKey = apiKey;
      await SignupService.signUpUserWithHackatime(
        SignupService.signUpUser,
        context,
      );
      if (!mounted) return;
      NavigationService.navigateTo(
        context: context,
        destination: AppDestination.home,
        colorScheme: Theme.of(context).colorScheme,
        textTheme: Theme.of(context).textTheme,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _apiController.dispose();
    super.dispose();
  }
}
