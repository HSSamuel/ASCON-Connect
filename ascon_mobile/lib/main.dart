import 'dart:async'; 
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required for defaultTargetPlatform
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'config/theme.dart';
import 'config.dart';
import 'router.dart'; 
import 'utils/error_handler.dart'; 

final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// ==========================================
// 🌙 BACKGROUND CALL HANDLER
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🌙 Background Message Received: ${message.messageId}");

  if (message.data['type'] == 'call_offer') {
    final data = message.data;
    
    CallKitParams params = CallKitParams(
      id: data['callLogId'],
      nameCaller: data['callerName'] ?? 'Unknown Member',
      appName: 'ASCON Connect',
      avatar: data['callerPic'],
      handle: data['callerId'],
      type: 0, // Audio Call
      duration: 30000,
      textAccept: 'Answer',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      extra: <String, dynamic>{
        ...data,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        backgroundColor: '#0F3621',
        ringtonePath: 'system_ringtone_default',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: "Incoming Call",
        isShowFullLockedScreen: true,
      ),
      ios: const IOSParams(
        iconName: 'CallKitIcon',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'videoChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}

void main() async {
  ErrorHandler.init();

  var defaultDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      if (message.contains("GSI_LOGGER")) return;
      if (message.contains("access_token")) return;
    }
    defaultDebugPrint(message, wrapWidth: wrapWidth);
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains("statusCode: 429")) return;
    FlutterError.presentError(details);
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await dotenv.load(fileName: ".env");
    
    SocketService().initSocket();

    // ✅ FIXED: Use defaultTargetPlatform for Web/Mobile/Desktop checks
    bool isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    bool isDesktop = defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux;

    if (kIsWeb || isMobile || isDesktop) {
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
        
        // ✅ FIXED: Only set background handler on Android/iOS
        if (isMobile) {
           FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        }
      }
    }

    // ✅ FIXED: Notification Service is Mobile-only for now
    if (!kIsWeb && isMobile) {
       await NotificationService().init();
    }

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    String errorText = error.toString();
    if (errorText.contains("Future already completed")) return;
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