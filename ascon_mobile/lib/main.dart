import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart'; 

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

  // ✅ 2. SILENCE GSI LOGS
  var defaultDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      if (message.contains("GSI_LOGGER")) return;
      if (message.contains("access_token")) return;
    }
    defaultDebugPrint(message, wrapWidth: wrapWidth);
  };

  // ✅ 3. SILENCE 429 IMAGE ERRORS
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains("statusCode: 429")) return;
    FlutterError.presentError(details);
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await dotenv.load(fileName: ".env");
    
    SocketService().initSocket();

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

    if (!kIsWeb) {
       await NotificationService().init();
    }

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    String errorText = error.toString();
    if (errorText.contains("Future already completed")) return;
    if (errorText.contains("FirebaseException") && errorText.contains("JavaScriptObject")) return;
    if (errorText.contains("AssetManifest.bin.json")) return;
    if (errorText.contains("deactivated widget")) return;
    // Also catch exception here for good measure
    if (errorText.contains("statusCode: 429")) return;

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
          builder: (context, child) {
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}