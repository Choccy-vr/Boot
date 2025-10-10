import 'package:boot_app/pages/Profile/profile_page.dart';
import 'package:boot_app/pages/Vote/vote_page.dart';
import 'package:boot_app/pages/test_vm_page.dart';
import 'package:boot_app/services/Projects/project.dart';
import 'package:boot_app/services/ships/ship_service.dart';
import 'package:boot_app/services/users/boot_user.dart';
import 'package:boot_app/services/users/user.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/animations/shared_axis.dart';
import '/services/dialog/dialog_service.dart';

import '/pages/test_page.dart';
import '/pages/Login/login_page.dart';
import '/pages/Login/SignUp/sign_up_page.dart';
import '/pages/home_page.dart';
import '/pages/Login/SignUp/signup_pass_page.dart';
import '/pages/Login/SignUp/sign_up_profile_page.dart';
import '/pages/Login/SignUp/sign_up_hackatime_page.dart';
import '/pages/Projects/my_projects_page.dart';
import '/pages/Projects/creation_page.dart';
import '/pages/Projects/project_page.dart';
import '/pages/Explore/explore_page.dart';

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
        _pushPage(context, const TestVmPage(), sharedAxis, transitionType);
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
      case AppDestination.vote:
        navigateToVote(context);
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

  static Future<void> navigateToVote(BuildContext context) async {
    final _ships = await ShipService.getShipsForVote(
      currentUserId: UserService.currentUser?.id ?? '',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VotePage(projects: [_ships])),
    );
  }
}
