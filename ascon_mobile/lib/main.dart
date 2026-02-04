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
    
    // Initialize Socket Service (Silent until login)
    SocketService().initSocket();

    // Firebase Initialization
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppConfig.firebaseWebApiKey, 
          authDomain: AppConfig.firebaseWebAuthDomain,
          projectId: AppConfig.firebaseWebProjectId,
          storageBucket: AppConfig.firebaseWebStorageBucket,
          messagingSenderId: AppConfig.firebaseWebMessagingSenderId,
          appId: AppConfig.firebaseWebAppId,
          measurementId: AppConfig.firebaseWebMeasurementId,
        ),
      );
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Notifications Initialization (Listeners only)
    if (!kIsWeb) {
       await NotificationService().init();
    }

    runApp(const MyApp());
  }, (error, stack) {
    // ========================================================
    // ✅ NOISE FILTER: Silence harmless Web/Async errors
    // ========================================================
    String errorText = error.toString();

    // 1. Logout Race Condition (Future completed twice)
    if (errorText.contains("Future already completed")) return;

    // 2. Firebase Web Internals (Harmless noise)
    if (errorText.contains("FirebaseException") && errorText.contains("JavaScriptObject")) return;

    // 3. Asset Manifest (Hot Restart Glitch)
    if (errorText.contains("AssetManifest.bin.json")) return;

    // Log genuine errors
    debugPrint("🔴 Uncaught Zone Error: $error");
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