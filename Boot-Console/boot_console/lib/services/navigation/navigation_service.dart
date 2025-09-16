import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '/animations/Shared_Axis.dart';

import '/pages/Home_Page.dart';
import '/pages/Login/Login_Page.dart';

enum AppDestination { home, login }

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
      case AppDestination.login:
        _pushPage(context, const LoginPage(), sharedAxis, transitionType);
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
