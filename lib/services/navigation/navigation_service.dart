import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/users/Boot_User.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:flutter/material.dart';
import '/services/dialog/dialog_service.dart';
import '/services/notifications/notifications.dart';

enum AppDestination {
  home,
  project,
  test,
  explore,
  leaderboard,
  challenges,
  shop,
  profile,
  login,
  signup,
  signupPass,
  signupProfile,
  signupSlack,
  createProject,
  admin,
  debug,
  reviewer,
}

class NavigationService {
  static void navigateTo({
    required BuildContext context,
    required AppDestination destination,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final navigator = Navigator.of(context);
    switch (destination) {
      case AppDestination.home:
        navigator.pushNamed('/dashboard');
        break;
      case AppDestination.project:
        navigator.pushNamed('/projects');
        break;
      case AppDestination.test:
        DialogService.showComingSoon(context, 'Test', textTheme, colorScheme);
        break;
      case AppDestination.login:
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
        break;
      case AppDestination.signup:
        navigator.pushNamed('/signup');
        break;
      case AppDestination.signupPass:
        navigator.pushNamed('/signup/password');
        break;
      case AppDestination.signupProfile:
        navigator.pushNamed('/signup/profile');
        break;
      case AppDestination.signupSlack:
        navigator.pushNamed('/signup/slack');
        break;

      case AppDestination.createProject:
        navigator.pushNamed('/projects/create');
        break;
      case AppDestination.explore:
        navigator.pushNamed('/explore');
        break;
      case AppDestination.leaderboard:
        navigator.pushNamed('/leaderboard');
        break;
      case AppDestination.challenges:
        navigator.pushNamed('/challenges');
        break;
      case AppDestination.shop:
        navigator.pushNamed('/shop');
        break;
      case AppDestination.profile:
        final user = UserService.currentUser;
        if (user == null) {
          GlobalNotificationService.instance.showWarning(
            'User profile not loaded yet.',
          );
          return;
        }
        navigator.pushNamed('/user/${user.id}', arguments: user);
        break;
      case AppDestination.admin:
        navigator.pushNamed('/admin');
        break;
      case AppDestination.debug:
        navigator.pushNamed('/debug');
        break;
      case AppDestination.reviewer:
        navigator.pushNamed('/reviewer');
        break;
    }
  }

  static Future<T?> openProject<T>(
    Project project,
    BuildContext context, {
    int? challengeId,
    bool showRequirements = false,
  }) {
    return Navigator.of(context).pushNamed<T>(
      '/projects/${project.id}',
      arguments: {
        'project': project,
        'challengeId': challengeId,
        'showRequirements': showRequirements,
      },
    );
  }

  static Future<T?> openProfile<T>(BootUser user, BuildContext context) {
    return Navigator.of(
      context,
    ).pushNamed<T>('/user/${user.id}', arguments: user);
  }
}
