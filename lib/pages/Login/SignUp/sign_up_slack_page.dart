import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/widgets/signup_step_indicator.dart';
import '../../../services/auth/Auth.dart';
import '/services/navigation/navigation_service.dart';
import '/services/users/signup/sign_up_service.dart';

class SignUpSlackPage extends StatefulWidget {
  const SignUpSlackPage({super.key});

  @override
  State<SignUpSlackPage> createState() => _SignUpSlackPageState();
}

class _SignUpSlackPageState extends State<SignUpSlackPage> {
  bool _isLoading = false;

  // Check if user signed up via Slack OAuth (email not stored in SignupService)
  bool get _isSlackOAuthUser => SignupService.signUpUser.email.isEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = screenWidth > 600 ? 500.0 : double.infinity;

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
                  const SignupStepIndicator(currentStep: 4, totalSteps: 4),
                  const SizedBox(height: 24),
                  _buildHeader(colorScheme, textTheme),
                  const SizedBox(height: 24),
                  if (_isSlackOAuthUser)
                    _buildAlreadyConnectedInfo(colorScheme, textTheme)
                  else
                    _buildSlackInfo(colorScheme, textTheme),
                  const SizedBox(height: 32),
                  if (_isSlackOAuthUser)
                    _buildContinueButton(colorScheme, textTheme)
                  else
                    _buildConnectButton(colorScheme, textTheme),
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
          Row(
            children: [
              Text(
                _isSlackOAuthUser ? 'You\'re all set!' : 'Almost there!',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isSlackOAuthUser ? '✅' : '🎉',
                style: TextStyle(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isSlackOAuthUser
                ? 'Your Slack account is already connected. You\'re ready to start using Boot!'
                : 'Connect your Slack account to complete your registration.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlackInfo(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4A154B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/images/slack_logo.svg',
              width: 48,
              height: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Connect with Hack Club Slack',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Boot is part of the Hack Club community. Connect your Slack account to:',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildBenefitItem(
            colorScheme,
            textTheme,
            Icons.login,
            'Easy login',
            'Sign in quickly with Slack next time',
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            colorScheme,
            textTheme,
            Icons.groups,
            'Join the community',
            'Connect with other Boot developers',
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            colorScheme,
            textTheme,
            Icons.emoji_events,
            'Participate in events',
            'Access Hack Club YSWS events',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    ColorScheme colorScheme,
    TextTheme textTheme,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlreadyConnectedInfo(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 48, color: Colors.green),
          ),
          const SizedBox(height: 20),
          Text(
            'Slack Connected',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You signed up with your Slack account, so you\'re already connected to the Hack Club community!',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4A154B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/slack_logo.svg',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hack Club Slack',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Connected via OAuth',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified, color: Colors.green, size: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          NavigationService.navigateTo(
            context: context,
            destination: AppDestination.home,
            colorScheme: colorScheme,
            textTheme: textTheme,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue to Dashboard',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectButton(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleConnectSlack,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A154B),
              foregroundColor: Colors.white,
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
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Connecting...',
                        style: textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/slack_logo.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Connect with Slack',
                        style: textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
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
                  'You\'ll be redirected to Slack to authorize Boot.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleConnectSlack() async {
    setState(() => _isLoading = true);

    try {
      // This will redirect to Slack OAuth
      // After successful auth, the user will be redirected back and
      // the app will detect they have completed setup and go to dashboard
      await Authentication.signInWithSlack();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to connect Slack: $e')));
      }
    }
  }
}
