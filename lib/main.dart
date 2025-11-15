import 'package:boot_app/services/Storage/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/Home_Page.dart';
import 'pages/Login/Login_Page.dart';
import 'pages/Login/SignUp/Signup_Pass_page.dart';
import 'pages/Login/SignUp/sign_up_hackatime_page.dart';
import 'pages/Login/SignUp/sign_up_page.dart';
import 'pages/Login/SignUp/sign_up_profile_page.dart';
import 'pages/Projects/Creation_Page.dart';
import 'pages/Projects/My_Projects_Page.dart';
import 'pages/Projects/Project_Page.dart';
import 'pages/Profile/Profile_Page.dart';
import 'pages/Explore/Explore_Page.dart';
import 'pages/Challenges/Challenge_page.dart';
import 'pages/not_found_page.dart';
import 'pages/Debug_Page.dart';
import 'services/Projects/Project.dart';
import 'services/Projects/project_service.dart';
import 'services/supabase/auth/Auth.dart';
import 'services/supabase/auth/supabase_auth.dart';
import 'services/supabase/auth/auth_listener.dart';
import 'services/misc/logger.dart';
import 'services/notifications/notifications.dart';
import 'services/users/Boot_User.dart';
import 'services/users/User.dart';
import 'theme/terminal_theme.dart';

const supabaseUrl = 'https://zbtphhtuaovleoxkoemt.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpidHBoaHR1YW92bGVveGtvZW10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NjU4MDEsImV4cCI6MjA3MTA0MTgwMX0.qogFGForru9M9rutCcMQSNJuGpP46LpLdWo03lvYqMQ';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  AppLogger.init();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  AuthListener.startListening();
  await SupabaseAuth.redirectCheck();
  final sessionRestored = await Authentication.restoreStoredSession();
  await StorageService.initialize();
  final initialRoute = sessionRestored ? '/dashboard' : '/login';
  runApp(MainApp(initialRoute: initialRoute));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boot App',
      theme: buildTerminalTheme(),
      initialRoute: initialRoute,
      builder: (context, child) {
        return NotificationScope(child: child ?? const SizedBox.shrink());
      },
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: _onUnknownRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}

Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final uri = Uri.parse(settings.name ?? '/');
  final segments = uri.pathSegments;
  final bool isLoggedIn = Authentication.isLoggedIn();

  if (segments.isEmpty) {
    final target = isLoggedIn ? '/dashboard' : '/login';
    final page = isLoggedIn ? const HomePage() : const LoginPage();
    return _buildRoute(child: page, name: target);
  }

  Widget? page;
  String routeName = uri.path.isEmpty ? '/' : uri.path;
  bool requiresAuth = true;

  switch (segments.first) {
    case 'login':
      page = const LoginPage();
      routeName = '/login';
      requiresAuth = false;
      break;
    case 'signup':
      requiresAuth = false;
      if (segments.length == 1) {
        page = const SignUpPage();
        routeName = '/signup';
      } else {
        final step = segments[1];
        switch (step) {
          case 'password':
            page = const SignUpPassPage();
            routeName = '/signup/password';
            break;
          case 'profile':
            page = const SignUpProfilePage();
            routeName = '/signup/profile';
            break;
          case 'hackatime':
            page = const SignupHackatimePage();
            routeName = '/signup/hackatime';
            break;
        }
      }
      break;
    case 'dashboard':
      page = const HomePage();
      routeName = '/dashboard';
      break;
    case 'projects':
      if (segments.length == 1) {
        page = const ProjectsPage();
        routeName = '/projects';
      } else {
        final second = segments[1];
        if (second == 'create') {
          page = const CreateProjectPage();
          routeName = '/projects/create';
        } else {
          final projectId = int.tryParse(second);
          if (projectId != null) {
            final projectArg = settings.arguments as Project?;
            page = ProjectLoaderPage(
              projectId: projectId,
              prefetchedProject: projectArg,
            );
            routeName = '/projects/$projectId';
          }
        }
      }
      break;
    case 'explore':
      page = const ExplorePage();
      routeName = '/explore';
      break;
    case 'challenges':
      page = const ChallengePage();
      routeName = '/challenges';
      break;
    case 'debug':
      page = const DebugPage();
      routeName = '/debug';
      break;
    case 'user':
      if (segments.length >= 2) {
        final userId = segments[1];
        if (userId.isNotEmpty) {
          final userArg = settings.arguments as BootUser?;
          page = UserLoaderPage(userId: userId, prefetchedUser: userArg);
          routeName = '/user/$userId';
        }
      }
      break;
  }

  if (page == null) {
    return _buildRoute(
      child: NotFoundPage(path: settings.name ?? uri.path),
      name: settings.name ?? uri.path,
    );
  }

  if (!isLoggedIn && requiresAuth) {
    return _buildRoute(child: const LoginPage(), name: '/login');
  }

  if (isLoggedIn && !requiresAuth) {
    return _buildRoute(child: const HomePage(), name: '/dashboard');
  }

  return _buildRoute(
    child: page,
    name: routeName,
    arguments: settings.arguments,
  );
}

Route<dynamic> _onUnknownRoute(RouteSettings settings) {
  final path = settings.name ?? '/unknown';
  return _buildRoute(
    child: NotFoundPage(path: path),
    name: path,
  );
}

Route<dynamic> _buildRoute({
  required Widget child,
  required String name,
  Object? arguments,
}) {
  final normalized = name.startsWith('/') ? name : '/$name';
  return MaterialPageRoute(
    builder: (context) => child,
    settings: RouteSettings(name: normalized, arguments: arguments),
  );
}

class ProjectLoaderPage extends StatelessWidget {
  const ProjectLoaderPage({
    super.key,
    required this.projectId,
    this.prefetchedProject,
  });

  final int projectId;
  final Project? prefetchedProject;

  @override
  Widget build(BuildContext context) {
    if (prefetchedProject != null) {
      return ProjectDetailPage(project: prefetchedProject!);
    }

    return FutureBuilder<Project?>(
      future: ProjectService.getProjectById(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }
        final project = snapshot.data;
        if (project == null) {
          return NotFoundPage(path: '/projects/$projectId');
        }
        return ProjectDetailPage(project: project);
      },
    );
  }
}

class UserLoaderPage extends StatelessWidget {
  const UserLoaderPage({super.key, required this.userId, this.prefetchedUser});

  final String userId;
  final BootUser? prefetchedUser;

  @override
  Widget build(BuildContext context) {
    if (prefetchedUser != null) {
      return ProfilePage(user: prefetchedUser!);
    }

    return FutureBuilder<BootUser?>(
      future: UserService.getUserById(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }
        final user = snapshot.data;
        if (user == null) {
          return NotFoundPage(path: '/user/$userId');
        }
        return ProfilePage(user: user);
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
