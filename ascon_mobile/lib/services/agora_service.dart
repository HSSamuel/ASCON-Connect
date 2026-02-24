import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'; // ✅ Added to check for Web

class AgoraService {
  // ✅ Made public so your CallScreen can access it to render Video views
  late RtcEngine engine; 
  bool isJoined = false;

  Future<void> initializeAgora({
    required bool isVideoCall, // ✅ Added parameter to support Video
    required Function(int uid) onUserJoined, 
    required Function(int uid) onUserOffline
  }) async {
    
    // ✅ FIX: Skip permission_handler on Web to prevent Error -4
    // Browsers automatically prompt the user when Agora requests the mic/camera
    if (!kIsWeb) {
      if (isVideoCall) {
        await [Permission.microphone, Permission.camera].request();
      } else {
        await [Permission.microphone].request();
      }
    }

    String appId = dotenv.env['AGORA_APP_ID'] ?? '';

    // Create the engine
    engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));

    // Listen for events
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          onUserJoined(remoteUid); // The other person answered!
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          onUserOffline(remoteUid); // The other person hung up!
        },
      ),
    );

    // Enable audio
    await engine.enableAudio();

    // ✅ ENABLE VIDEO if the user pressed the Video Call button
    if (isVideoCall) {
      await engine.enableVideo();
    }
  }

  Future<void> joinCall({required String token, required String channelName}) async {
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication, // Perfect for 1-on-1 calls
      ),
    );
  }

  Future<void> leaveCall() async {
    if (isJoined) {
      await engine.leaveChannel();
      isJoined = false;
    }
  }

  Future<void> dispose() async {
    await engine.release();
  }
}