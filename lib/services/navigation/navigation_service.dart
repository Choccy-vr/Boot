import 'package:boot_app/pages/Profile/Profile_Page.dart';
import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/users/Boot_User.dart';
import 'package:boot_app/services/users/User.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '/animations/Shared_Axis.dart';
import '/services/dialog/dialog_service.dart';

import '/pages/Test_Page.dart';
import '/pages/Login/Login_Page.dart';
import '/pages/Login/SignUp/sign_up_page.dart';
import '/pages/Home_Page.dart';
import '/pages/Login/SignUp/Signup_Pass_page.dart';
import '/pages/Login/SignUp/sign_up_profile_page.dart';
import '/pages/Login/SignUp/sign_up_hackatime_page.dart';
import '/pages/Projects/My_Projects_Page.dart';
import '/pages/Projects/Creation_Page.dart';
import '/pages/Projects/Project_Page.dart';
import '/pages/Explore/Explore_Page.dart';

enum AppDestination {
  home,
  project,
  test,
  explore,
  leaderboard,
  profile,
  login,
  signup,
  signupPass,
  signupProfile,
  signupHackatime,
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
        _pushPage(context, const SignUpPassPage(), sharedAxis, transitionType);
        break;
      case AppDestination.signupProfile:
        _pushPage(
          context,
          const SignUpProfilePage(),
          sharedAxis,
          transitionType,
        );
        break;
      case AppDestination.signupHackatime:
        _pushPage(
          context,
          const SignupHackatimePage(),
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
      case AppDestination.explore:
        _pushPage(context, const ExplorePage(), sharedAxis, transitionType);
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
        openProfile(UserService.currentUser!, context);
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

  static void openProject(Project project, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailPage(project: project),
      ),
    );
  }

  static void openProfile(BootUser user, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(user: user)),
    );
  }
}
