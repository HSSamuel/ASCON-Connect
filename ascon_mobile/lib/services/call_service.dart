import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ascon_mobile/services/api_client.dart'; 

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  String? _myIdentity;
  bool _isInitialized = false;

  // Listen to call events 
  Stream<CallEvent> get callEvents => TwilioVoice.instance.callEventsListener;

  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint("🔄 Initializing Twilio Voice...");

    // 1. Request Permissions (Mobile only)
    if (!kIsWeb) {
      await [Permission.microphone, Permission.notification, Permission.phone].request();
    }

    // 2. Get FCM Token (Required for Android, skipped on Web/iOS if not needed)
    String? fcmToken;
    try {
       fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
       debugPrint("⚠️ FCM Token Warning: $e");
    }

    // 3. Get Access Token from Your Backend
    try {
      // ✅ FIX: Added '/api' to the endpoint to match server.js
      final response = await ApiClient().get('/api/twilio/token'); 
      
      if (response['data'] != null && response['data']['token'] != null) {
        String accessToken = response['data']['token'];
        _myIdentity = response['data']['identity'];

        // 4. Register with Twilio
        // ✅ FIX: Handle null return with ?? false for Web compatibility
        bool success = await TwilioVoice.instance.setTokens(
          accessToken: accessToken, 
          deviceToken: fcmToken
        ) ?? false;

        if (success) {
          _isInitialized = true;
          debugPrint("✅ Twilio Registered successfully as: $_myIdentity");
        } else {
          debugPrint("❌ Twilio Registration Failed: setTokens returned false");
        }
      } else {
        debugPrint("❌ Twilio Init Error: Token missing in response $response");
      }
    } catch (e) {
      debugPrint("❌ Twilio Init Error: $e");
    }
  }

  Future<bool> placeCall(String recipientId, String recipientName) async {
    // Ensure we are initialized before calling
    if (!_isInitialized) await init();

    if (!_isInitialized) {
      debugPrint("⛔ Cannot place call: Twilio not initialized.");
      return false;
    }

    debugPrint("📞 Calling $recipientName ($recipientId)...");
    
    // ✅ FIX: Null safety return
    return await TwilioVoice.instance.call.place(
      to: recipientId, 
      from: _myIdentity ?? "Ascon User",
      extraOptions: {"recipientName": recipientName}
    ) ?? false;
  }

  Future<void> hangUp() async {
    // ✅ FIX: Use hangUp() (CamelCase)
    await TwilioVoice.instance.call.hangUp();
  }

  Future<void> toggleMute(bool isMuted) async {
    await TwilioVoice.instance.call.toggleMute(isMuted);
  }

  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    await TwilioVoice.instance.call.toggleSpeaker(isSpeakerOn);
  }
}