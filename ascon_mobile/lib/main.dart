import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 

// ✅ Services & Config
import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'config/theme.dart';
import 'config.dart'; // Import for AppConfig if needed
import 'router.dart'; // ✅ Import the Router

// ✅ Global Key: Aliased to the Router's key so NotificationService works
final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;

// ✅ DEFINE CHANNEL ID
const String channelId = 'ascon_high_importance'; 
const String channelName = 'ASCON Notifications';

// ✅ GLOBAL THEME CONTROLLER
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// ✅ BACKGROUND HANDLER
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🌙 Background Message Received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ LOAD ENV FIRST
  await dotenv.load(fileName: ".env");

  // ✅ Initialize Socket Service
  SocketService().initSocket();

  // 1. INITIALIZE FIREBASE
  if (kIsWeb) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: dotenv.env['FIREBASE_API_KEY'] ?? "",
            appId: dotenv.env['FIREBASE_APP_ID'] ?? "",
            messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? "",
            projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? "",
            storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? "",
          ),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Firebase Web Init Error: $e");
    }
  } else {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // 2. INITIALIZE NOTIFICATIONS (Mobile Only)
  if (!kIsWeb) {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId, 
        channelName, 
        description: 'This channel is used for important ASCON updates.',
        importance: Importance.max, 
        playSound: true,
        enableVibration: true,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await NotificationService().init();
      debugPrint("✅ Notifications Initialized Successfully");
    } catch (e) {
      debugPrint("⚠️ Notification Init Failed: $e");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        // ✅ CHANGED: Use MaterialApp.router
        return MaterialApp.router(
          routerConfig: appRouter, // Connects GoRouter
          title: 'ASCON Alumni',
          debugShowCheckedModeBanner: false,

          // Themes
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          
          themeMode: currentMode, 
        );
      },
    );
  }
}