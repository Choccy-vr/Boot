import 'package:boot_app/services/Storage/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html show window;

import 'pages/Home_Page.dart' deferred as home_page;
import 'pages/Login/Login_Page.dart';
import 'pages/Login/SignUp/Signup_Pass_page.dart';
import 'pages/Login/SignUp/sign_up_page.dart';
import 'pages/Login/SignUp/sign_up_profile_page.dart';
import 'pages/Login/SignUp/sign_up_slack_page.dart';
import 'pages/Projects/Creation_Page.dart' deferred as creation_page;
import 'pages/Projects/My_Projects_Page.dart' deferred as projects_page;
import 'pages/Projects/Project_Page.dart' deferred as project_page;
import 'pages/Profile/Profile_Page.dart' deferred as profile_page;
import 'pages/Explore/Explore_Page.dart' deferred as explore_page;
import 'pages/Challenges/Challenge_page.dart' deferred as challenge_page;
import 'pages/Reviewer/Reviewer_Page.dart' deferred as reviewer_page;
import 'pages/not_found_page.dart';
import 'pages/Debug_Page.dart';
import 'pages/Maintenance_Page.dart';
import 'pages/Admin/Admin_Page.dart' deferred as admin_page;
import 'pages/Shop/Shop_Page.dart' deferred as shop_page;
import 'pages/Shop/Prize_Details_Page.dart' deferred as prize_details_page;
import 'pages/Leaderboard/Leaderboard_Page.dart' deferred as leaderboard_page;
import 'services/Projects/Project.dart';
import 'services/Projects/project_service.dart';
import 'services/auth/Auth.dart';
import 'services/auth/supabase_auth.dart';
import 'services/auth/auth_listener.dart';
import 'services/misc/logger.dart';
import 'services/notifications/notifications.dart';
import 'services/users/Boot_User.dart';
import 'services/users/User.dart';
import 'services/prizes/Prize.dart';
import 'services/prizes/Prize_Service.dart';
import 'theme/terminal_theme.dart';
import 'widgets/deferred_page.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const hackclubClientId = String.fromEnvironment('HACKCLUB_CLIENT_ID');

// Maintenance Mode - Set to true to enable, false to disable
bool isMaintenanceModeEnabled = !isRunningOnLocalhost();

bool isRunningOnLocalhost() {
  if (!kIsWeb) return kDebugMode;
  
  try {
    final hostname = Uri.base.host;
    return hostname == 'localhost' || 
           hostname == '127.0.0.1' || 
            hostname.startsWith('localhost:') ||
            hostname.startsWith('127.0.0.1:');
} catch (e) {
    return false;
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  AppLogger.init();

  // Parallelize initialization for faster startup
  await Future.wait([
    Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey),
    StorageService.initialize(),
  ]);

  AuthListener.startListening();

  // Configure Hack Club OAuth (no async init needed)
  Authentication.configureHackClubOAuth(
    clientId: hackclubClientId,
    redirectUri: isRunningOnLocalhost()
        ? '${Uri.base.origin}/redirect.html'
        : '${Uri.base.origin}/dashboard/redirect.html',
  );

  // Run auth checks in parallel
  final results = await Future.wait([
    SupabaseAuth.redirectCheck(),
    _handleHackClubCallback(),
    Authentication.restoreStoredSession(),
  ]);

  final sessionRestored = results[2] as bool;

  String initialRoute = '/login';
  if (sessionRestored) {
    initialRoute = '/dashboard';
  }

  runApp(MainApp(initialRoute: initialRoute));
}

Future<void> _handleHackClubCallback() async {
  // Check for Hack Club OAuth callback (web only)
  if (kIsWeb) {
    try {
      final callbackUrl = html.window.sessionStorage['hackclub_callback'];
      if (callbackUrl != null && callbackUrl.isNotEmpty) {
        html.window.sessionStorage.remove('hackclub_callback');
        final callbackUri = Uri.parse(callbackUrl);
        await Authentication.handleHackClubCallback(callbackUri);
      }
    } catch (e) {
      AppLogger.error('Error handling Hack Club callback', e);
    }
  }
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
  final UserRole? currentRole = UserService.currentUser?.role;

  // Maintenance mode check - allow owners through, show maintenance page to everyone else
  if (isMaintenanceModeEnabled) {
    final isOwner = currentRole == UserRole.owner;
    final isLoginOrSignupPage = segments.isEmpty || 
                                 segments.first == 'login' || 
                                 segments.first == 'signup';
    
    // If not an owner and not trying to access login/signup, show maintenance page
    if (!isOwner && !isLoginOrSignupPage) {
      return _buildRoute(
        child: const MaintenancePage(),
        name: '/maintenance',
      );
    }
  }

  if (segments.isEmpty) {
    final target = isLoggedIn ? '/dashboard' : '/login';
    final page = isLoggedIn
        ? DeferredPage(
            loadLibrary: home_page.loadLibrary,
            buildPage: (_) => home_page.HomePage(),
            placeholder: const _LoadingScaffold(),
          )
        : const LoginPage();
    return _buildRoute(child: page, name: target);
  }

  Widget? page;
  String routeName = uri.path.isEmpty ? '/' : uri.path;
  bool requiresAuth = true;
  Set<UserRole>? requiredRoles;

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
          case 'slack':
            page = const SignUpSlackPage();
            routeName = '/signup/slack';
            break;
        }
      }
      break;
    case 'dashboard':
      page = DeferredPage(
        loadLibrary: home_page.loadLibrary,
        buildPage: (_) => home_page.HomePage(),
        placeholder: const _LoadingScaffold(),
      );
      routeName = '/dashboard';
      break;
    case 'projects':
      if (segments.length == 1) {
        page = DeferredPage(
          loadLibrary: projects_page.loadLibrary,
          buildPage: (_) => projects_page.ProjectsPage(),
          placeholder: const _LoadingScaffold(),
        );
        routeName = '/projects';
      } else {
        final second = segments[1];
        if (second == 'create') {
          page = DeferredPage(
            loadLibrary: creation_page.loadLibrary,
            buildPage: (_) => creation_page.CreateProjectPage(),
            placeholder: const _LoadingScaffold(),
          );
          routeName = '/projects/create';
        } else {
          final projectId = int.tryParse(second);
          if (projectId != null) {
            Project? prefetchedProject;
            Object? arg = settings.arguments;
            if (arg is Map) {
              prefetchedProject = arg['project'] as Project?;
            } else if (arg is Project) {
              prefetchedProject = arg;
            }

            page = ProjectLoaderPage(
              projectId: projectId,
              prefetchedProject: prefetchedProject,
            );
            routeName = '/projects/$projectId';
          }
        }
      }
      break;
    case 'explore':
      page = DeferredPage(
        loadLibrary: explore_page.loadLibrary,
        buildPage: (_) => explore_page.ExplorePage(),
        placeholder: const _LoadingScaffold(),
      );
      routeName = '/explore';
      break;
    case 'challenges':
      page = DeferredPage(
        loadLibrary: challenge_page.loadLibrary,
        buildPage: (_) => challenge_page.ChallengePage(),
        placeholder: const _LoadingScaffold(),
      );
      routeName = '/challenges';
      break;
    case 'leaderboard':
      page = DeferredPage(
        loadLibrary: leaderboard_page.loadLibrary,
        buildPage: (_) => leaderboard_page.LeaderboardPage(),
        placeholder: const _LoadingScaffold(),
      );
      routeName = '/leaderboard';
      break;
    case 'reviewer':
      requiredRoles = {UserRole.reviewer, UserRole.admin, UserRole.owner};
      page = DeferredPage(
        loadLibrary: reviewer_page.loadLibrary,
        buildPage: (_) => reviewer_page.ReviewerPage(),
        placeholder: const _LoadingScaffold(),
      );
      routeName = '/reviewer';
      break;
    case 'debug':
      page = const DebugPage();
      routeName = '/debug';
      break;
    case 'admin':
      requiredRoles = {UserRole.admin, UserRole.owner};
      page = DeferredPage(
        loadLibrary: admin_page.loadLibrary,
        buildPage: (_) => admin_page.AdminPage(),
        placeholder: const _LoadingScaffold(),
      );
      routeName = '/admin';
      break;
    case 'shop':
      page = DeferredPage(
        loadLibrary: shop_page.loadLibrary,
        buildPage: (_) => shop_page.ShopPage(),
        placeholder: const _LoadingScaffold(),
      );
      routeName = '/shop';
      break;
    case 'prizes':
      if (segments.length >= 2) {
        final prizeId = segments[1];
        if (prizeId.isNotEmpty) {
          // Prize details page will load the prize
          page = PrizeLoaderPage(prizeId: prizeId);
          routeName = '/prizes/$prizeId';
        }
      }
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

  if (requiredRoles != null && !requiredRoles.contains(currentRole)) {
    return _buildRoute(
      child: DeferredPage(
        loadLibrary: home_page.loadLibrary,
        buildPage: (_) => home_page.HomePage(),
        placeholder: const _LoadingScaffold(),
      ),
      name: '/dashboard',
    );
  }

  // Allow logged-in users to access signup flow pages (profile, hackatime setup)
  // but redirect them from login page to dashboard
  if (isLoggedIn && !requiresAuth && segments.first == 'login') {
    return _buildRoute(
      child: DeferredPage(
        loadLibrary: home_page.loadLibrary,
        buildPage: (_) => home_page.HomePage(),
        placeholder: const _LoadingScaffold(),
      ),
      name: '/dashboard',
    );
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
    final args = ModalRoute.of(context)?.settings.arguments;
    Project? project;
    int? challengeId;
    bool showRequirementsDialog = false;

    // Handle different argument types
    try {
      if (args != null) {
        // Try to handle as Map first (most common case)
        if (args is Map) {
          final map = args;
          project = map['project'] as Project?;
          challengeId = map['challengeId'] as int?;
          showRequirementsDialog = map['showRequirements'] as bool? ?? false;
        }
        // Fallback to direct Project if not a Map
        if (project == null && args is Project) {
          project = args;
        }
      }
    } catch (e) {
      // If extraction fails, project will be null and we'll fetch by ID
    }

    // Fallback to prefetched project if available
    if (project == null && prefetchedProject != null) {
      project = prefetchedProject;
    }

    if (project != null) {
      return DeferredPage(
        loadLibrary: project_page.loadLibrary,
        buildPage: (_) => project_page.ProjectDetailPage(
          project: project!,
          challengeId: challengeId,
          showRequirementsDialog: showRequirementsDialog,
        ),
        placeholder: const _LoadingScaffold(),
      );
    }

    // Fetch project by ID if not in arguments
    return FutureBuilder<Project?>(
      future: ProjectService.getProjectById(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }
        final fetchedProject = snapshot.data;
        if (fetchedProject == null) {
          return NotFoundPage(path: '/projects/$projectId');
        }
        return DeferredPage(
          loadLibrary: project_page.loadLibrary,
          buildPage: (_) => project_page.ProjectDetailPage(
            project: fetchedProject,
            showRequirementsDialog: showRequirementsDialog,
          ),
          placeholder: const _LoadingScaffold(),
        );
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
      return DeferredPage(
        loadLibrary: profile_page.loadLibrary,
        buildPage: (_) => profile_page.ProfilePage(user: prefetchedUser!),
        placeholder: const _LoadingScaffold(),
      );
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
        return DeferredPage(
          loadLibrary: profile_page.loadLibrary,
          buildPage: (_) => profile_page.ProfilePage(user: user),
          placeholder: const _LoadingScaffold(),
        );
      },
    );
  }
}

class PrizeLoaderPage extends StatelessWidget {
  const PrizeLoaderPage({super.key, required this.prizeId});

  final String prizeId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Prize>>(
      future: PrizeService.fetchPrizes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }
        final prizes = snapshot.data ?? [];
        final prize = prizes.where((p) => p.id == prizeId).firstOrNull;

        if (prize == null) {
          return NotFoundPage(path: '/prizes/$prizeId');
        }

        // Get cart state from current user
        final cartItems = Set<String>.from(UserService.currentUser?.cart ?? []);
        final isInCart = cartItems.contains(prizeId);

        // For now, quantity is 1, but this could be tracked in user's cart data
        return DeferredPage(
          loadLibrary: prize_details_page.loadLibrary,
          buildPage: (_) => prize_details_page.PrizeDetailsPage(
            prize: prize,
            isInCart: isInCart,
            currentQuantity: 1,
            onAddToCart: (prizeId, qty) async {
              // Update cart
              final user = UserService.currentUser;
              if (user != null) {
                if (!user.cart.contains(prizeId)) {
                  user.cart.add(prizeId);
                  await UserService.updateUser();
                }
              }
            },
          ),
          placeholder: const _LoadingScaffold(),
        );
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
