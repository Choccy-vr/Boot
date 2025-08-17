import 'package:flutter/material.dart';
import '../pages/Test_Page.dart';
import 'dialog_service.dart';

class NavigationService {
  static void navigateTo(
    BuildContext context,
    String destination,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    switch (destination) {
      case 'build':
        // Navigate to build screen
        DialogService.showComingSoon(context, 'Build', textTheme, colorScheme);
        break;
      case 'test':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TestPage()),
        );
        break;
      case 'vote':
        DialogService.showComingSoon(context, 'Vote', textTheme, colorScheme);
        break;
      case 'explore':
        DialogService.showComingSoon(
          context,
          'Explore',
          textTheme,
          colorScheme,
        );
        break;
      case 'leaderboard':
        DialogService.showComingSoon(
          context,
          'Leaderboard',
          textTheme,
          colorScheme,
        );
        break;
      case 'profile':
        DialogService.showComingSoon(
          context,
          'Profile',
          textTheme,
          colorScheme,
        );
        break;
    }
  }
}
