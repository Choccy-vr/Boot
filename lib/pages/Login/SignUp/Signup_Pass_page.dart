import 'package:flutter/material.dart';
import '../../../services/navigation/navigation_service.dart';
import '/services/users/signup/sign_up_service.dart';
import '/widgets/signup_step_indicator.dart';

class SignUpPassPage extends StatefulWidget {
  const SignUpPassPage({super.key});

  @override
  State<SignUpPassPage> createState() => _SignUpPassPageState();
}

class _SignUpPassPageState extends State<SignUpPassPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = screenWidth > 600 ? 450.0 : double.infinity;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  const SignupStepIndicator(currentStep: 2, totalSteps: 4),
                  const SizedBox(height: 24),
                  _buildHeader(colorScheme, textTheme),
                  const SizedBox(height: 24),
                  _buildPasswordFields(colorScheme, textTheme),
                  const SizedBox(height: 32),
                  _buildButtons(colorScheme, textTheme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, color: colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'boot ~ signup',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Secure your account',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a strong password to protect your account.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFields(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 2: Password',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Choose a secure password',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            enabled: !_isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            enabled: !_isLoading,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSignUp(),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Re-enter your password',
              prefixIcon: Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use at least 8 characters with a mix of letters and numbers.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          NavigationService.navigateTo(
                            context: context,
                            destination: AppDestination.signup,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Back',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                              'Creating...',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: colorScheme.onPrimary,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  NavigationService.navigateTo(
                    context: context,
                    destination: AppDestination.login,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  );
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Already have an account? ', style: textTheme.bodyMedium),
              Text(
                'Log In',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSignUp() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }

    if (confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please confirm your password')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      SignupService.signUpUser.password = password;
      await SignupService.signUp(SignupService.signUpUser);
      if (!mounted) return;
      NavigationService.navigateTo(
        context: context,
        destination: AppDestination.signupProfile,
        colorScheme: Theme.of(context).colorScheme,
        textTheme: Theme.of(context).textTheme,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
