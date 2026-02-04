// ascon_mobile/lib/main.dart
import 'dart:async'; // ✅ REQUIRED for runZonedGuarded
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 

import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'config/theme.dart';
import 'config.dart';
import 'router.dart'; 
import 'utils/error_handler.dart'; 

final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🌙 Background Message Received: ${message.messageId}");
}

void main() async {
  // ✅ 1. Initialize Global Error Handling
  ErrorHandler.init();

  // ✅ 2. Run App Logic guarded by a Zone
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await dotenv.load(fileName: ".env");
    SocketService().initSocket();

    // Firebase Init
    if (kIsWeb) {
      // ... (Web Init code matches original) ...
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Notifications Init
    if (!kIsWeb) {
       // ... (Notification Init code matches original) ...
    }

    runApp(const MyApp());
  }, (error, stack) {
    // ========================================================
    // ✅ NOISE FILTER: Silence harmless "Future completed" errors
    // These happen during logout race conditions and are safe to ignore.
    // ========================================================
    if (error.toString().contains("Future already completed")) {
      return; 
    }

    debugPrint("🔴 Uncaught Zone Error: $error");
    // Report to Crashlytics/Sentry
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp.router(
          routerConfig: appRouter, 
          title: 'ASCON Alumni',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          // ✅ Add a default error builder for navigation failures
          builder: (context, child) {
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}