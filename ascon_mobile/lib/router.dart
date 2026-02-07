import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; 
import 'screens/events_screen.dart';
import 'screens/updates_screen.dart';
import 'screens/directory_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/about_screen.dart';
import 'screens/polls_screen.dart'; // ✅ NEW: Import Polls Screen

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // Shell Route Wraps the Bottom Navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeScreen(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardView(),
            ),
          ],
        ),
        
        // Tab 1: Events
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsScreen(),
            ),
          ],
        ),

        // Tab 2: Updates
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/updates',
              builder: (context, state) => const UpdatesScreen(),
            ),
          ],
        ),

        // Tab 3: Directory
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/directory',
              builder: (context, state) => const DirectoryScreen(),
            ),
          ],
        ),

        // Tab 4: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) {
                final name = state.extra as String?;
                return ProfileScreen(userName: name);
              },
            ),
          ],
        ),
      ],
    ),

    // Standalone Screens
    GoRoute(
      path: '/chat',
      parentNavigatorKey: rootNavigatorKey, 
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    
    // ✅ NEW: Polls History Route
    // This allows push notifications to open 'route: polls'
    GoRoute(
      path: '/polls',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PollsScreen(),
    ),
  ],
);