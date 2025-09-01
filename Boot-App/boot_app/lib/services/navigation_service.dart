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
import '/pages/Projects/Project_Page.dart';
import '/pages/Projects/Creation_Page.dart';

enum AppDestination {
  home,
  project,
  test,
  vote,
  explore,
  leaderboard,
  profile,
  login,
  signup,
  signupPass,
  signupProfile,
  createProject,
}

class NavigationService {
  static void navigateTo({
    required BuildContext context,
    required AppDestination destination,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    bool sharedAxis = false,
    SharedAxisTransitionType transitionType =
        SharedAxisTransitionType.horizontal,
  }) {
    switch (destination) {
      case AppDestination.home:
        _pushPage(context, const HomePage(), sharedAxis, transitionType);
        break;
      case AppDestination.project:
        _pushPage(context, const ProjectsPage(), sharedAxis, transitionType);
        break;
      case AppDestination.test:
        _pushPage(context, const TestPage(), sharedAxis, transitionType);
        break;
      case AppDestination.login:
        _pushPage(context, const LoginPage(), sharedAxis, transitionType);
        break;
      case AppDestination.signup:
        _pushPage(context, const SignUpPage(), sharedAxis, transitionType);
        break;
      case AppDestination.signupPass:
        _pushPage(
          context,
          const SignUp_Pass_Page(),
          sharedAxis,
          transitionType,
        );
        break;
      case AppDestination.signupProfile:
        _pushPage(
          context,
          const SignUp_Profile_Page(),
          sharedAxis,
          transitionType,
        );
        break;
      case AppDestination.createProject:
        _pushPage(
          context,
          const CreateProjectPage(),
          sharedAxis,
          transitionType,
        );
        break;
      case AppDestination.vote:
        DialogService.showComingSoon(context, 'Vote', textTheme, colorScheme);
        break;
      case AppDestination.explore:
        DialogService.showComingSoon(
          context,
          'Explore',
          textTheme,
          colorScheme,
        );
        break;
      case AppDestination.leaderboard:
        DialogService.showComingSoon(
          context,
          'Leaderboard',
          textTheme,
          colorScheme,
        );
        break;
      case AppDestination.profile:
        DialogService.showComingSoon(
          context,
          'Profile',
          textTheme,
          colorScheme,
        );
        break;
    }
  }

  static void _pushPage(
    BuildContext context,
    Widget page,
    bool sharedAxis,
    SharedAxisTransitionType transitionType,
  ) {
    Navigator.push(
      context,
      sharedAxis
          ? SharedAxisPageRoute(child: page, transitionType: transitionType)
          : MaterialPageRoute(builder: (context) => page),
    );
  }
}
