import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AgoraService {
  late RtcEngine _engine;
  bool isJoined = false;

  Future<void> initializeAgora(Function(int uid) onUserJoined, Function(int uid) onUserOffline) async {
    // Request microphone permission
    await [Permission.microphone].request();

    String appId = dotenv.env['AGORA_APP_ID'] ?? '';

    // Create the engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    // Listen for events (like when the other person picks up or hangs up)
    _engine.registerEventHandler(
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
    await _engine.enableAudio();
  }

  Future<void> joinCall({required String token, required String channelName}) async {
    await _engine.joinChannel(
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
      await _engine.leaveChannel();
      isJoined = false;
    }
  }

  Future<void> dispose() async {
    await _engine.release();
  }
}