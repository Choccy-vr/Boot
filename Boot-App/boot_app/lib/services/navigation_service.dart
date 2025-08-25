import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '/animations/Shared_Axis.dart';
import 'dialog_service.dart';

import '/pages/Test_Page.dart';
import '/pages/Login/Login_Page.dart';
import '/pages/Login/SignUp/SignUp_Page.dart';
import '/pages/Home_Page.dart';
import '/pages/Login/SignUp/Signup_Pass_page.dart';
import '/pages/Login/SignUp/SignUp_Profile_Page.dart';

class NavigationService {
  static void navigateTo({
    required BuildContext context,
    required String destination,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    bool sharedAxis = false,
    SharedAxisTransitionType transitionType =
        SharedAxisTransitionType.horizontal,
  }) {
    switch (destination) {
      case 'home':
        Navigator.push(
          context,
          sharedAxis
              ? SharedAxisPageRoute(
                  child: const HomePage(),
                  transitionType: transitionType,
                )
              : MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 'build':
        // Navigate to build screen
        DialogService.showComingSoon(context, 'Build', textTheme, colorScheme);
        break;
      case 'test':
        Navigator.push(
          context,
          sharedAxis
              ? SharedAxisPageRoute(
                  child: const TestPage(),
                  transitionType: transitionType,
                )
              : MaterialPageRoute(builder: (context) => const TestPage()),
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
      case 'login':
        Navigator.push(
          context,
          sharedAxis
              ? SharedAxisPageRoute(
                  child: const LoginPage(),
                  transitionType: transitionType,
                )
              : MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        break;
      case 'signup':
        Navigator.push(
          context,
          sharedAxis
              ? SharedAxisPageRoute(
                  child: const SignUpPage(),
                  transitionType: transitionType,
                )
              : MaterialPageRoute(builder: (context) => const SignUpPage()),
        );
      case 'signup_pass':
        Navigator.push(
          context,
          sharedAxis
              ? SharedAxisPageRoute(
                  child: const SignUp_Pass_Page(),
                  transitionType: transitionType,
                )
              : MaterialPageRoute(
                  builder: (context) => const SignUp_Pass_Page(),
                ),
        );
      case 'signup_profile':
        Navigator.push(
          context,
          sharedAxis
              ? SharedAxisPageRoute(
                  child: const SignUp_Profile_Page(),
                  transitionType: transitionType,
                )
              : MaterialPageRoute(
                  builder: (context) => const SignUp_Profile_Page(),
                ),
        );
    }
  }
}
