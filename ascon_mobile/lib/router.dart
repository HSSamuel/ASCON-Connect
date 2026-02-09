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
import 'screens/chat_screen.dart';
import 'screens/about_screen.dart';
import 'screens/polls_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
// ✅ Keys for tabs to ensure separate stacks
final GlobalKey<NavigatorState> homeNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> eventsNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> updatesNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> directoryNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> profileNavKey = GlobalKey<NavigatorState>();

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
          navigatorKey: homeNavKey, // ✅ Added Key
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardView(),
            ),
          ],
        ),
        
        // Tab 1: Events
        StatefulShellBranch(
          navigatorKey: eventsNavKey, // ✅ Added Key
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsScreen(),
            ),
          ],
        ),

        // Tab 2: Updates
        StatefulShellBranch(
          navigatorKey: updatesNavKey, // ✅ Added Key
          routes: [
            GoRoute(
              path: '/updates',
              builder: (context, state) => const UpdatesScreen(),
            ),
          ],
        ),

        // Tab 3: Directory
        StatefulShellBranch(
          navigatorKey: directoryNavKey, // ✅ Added Key
          routes: [
            GoRoute(
              path: '/directory',
              builder: (context, state) => const DirectoryScreen(),
            ),
          ],
        ),

        // Tab 4: Profile
        StatefulShellBranch(
          navigatorKey: profileNavKey, // ✅ Added Key
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

    // Standalone Screens (Outside Shell)
    GoRoute(
      path: '/chat',
      parentNavigatorKey: rootNavigatorKey, 
      builder: (context, state) => const ChatListScreen(),
    ),
    
    GoRoute(
      path: '/chat_detail',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return ChatScreen( 
          conversationId: args['conversationId'],
          receiverId: args['receiverId'],
          receiverName: args['receiverName'],
          receiverProfilePic: args['receiverProfilePic'],
          isOnline: args['isOnline'] ?? false,
          lastSeen: args['lastSeen'],
          isGroup: args['isGroup'] ?? false,
          groupId: args['groupId'],
        );
      },
    ),

    GoRoute(
      path: '/about',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    
    GoRoute(
      path: '/polls',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PollsScreen(),
    ),
  ],
);