import 'package:flutter/material.dart';
import '../../services/hackatime/hackatime_service.dart';
import '../../services/misc/logger.dart';

class HackatimeLoginPage extends StatefulWidget {
  const HackatimeLoginPage({super.key});

  @override
  State<HackatimeLoginPage> createState() => _HackatimeLoginPageState();
}

class _HackatimeLoginPageState extends State<HackatimeLoginPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
  }

  Future<void> _checkAuthAndRedirect() async {
    // If somehow we land on Hackatime login but are already authenticated,
    // redirect to dashboard immediately.
    final isAuthenticated = await HackatimeService.isAuthenticated();
    if (isAuthenticated && mounted) {
      AppLogger.info(
        'Hackatime login page detected existing authentication; redirecting to dashboard.',
      );
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = screenWidth > 600 ? 400.0 : double.infinity;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connect Hackatime',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with Hackatime to continue',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleHackatimeLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Continue with Hackatime',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleHackatimeLogin() async {
    setState(() => _isLoading = true);

    try {
      await HackatimeService.signInWithHackatime();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hackatime login failed: $e')));
    }
  }
}
