import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ascon_mobile/services/api_client.dart';

enum CallEvent { ringing, connected, callEnded, error }

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  late RtcEngine _engine;
  bool _isInitialized = false;
  bool isJoined = false;

  final _callEventController = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get callEvents => _callEventController.stream;

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Request microphone permissions
    if (!kIsWeb) {
      await [Permission.microphone].request();
    }

    // 2. Load Agora App ID from env.txt
    String appId = dotenv.env['AGORA_APP_ID'] ?? '';
    if (appId.isEmpty) {
      debugPrint("❌ Agora App ID is missing from env.txt");
      return;
    }

    // 3. Initialize the Agora Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
  RtcEngineContext(
    appId: appId,
    logConfig: const LogConfig(
      level: LogLevel.logLevelError, // 🔥 This silences all the DEBUG/INFO spam!
    ),
  ),
);

    // 4. Listen for Call Events (when the other person answers or hangs up)
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ Agora Joined Channel: ${connection.channelId}");
          isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("📞 Remote user answered! UID: $remoteUid");
          _callEventController.add(CallEvent.connected);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("📞 Remote user hung up! UID: $remoteUid");
          _callEventController.add(CallEvent.callEnded);
          leaveCall();
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora Error: $err - $msg");
          _callEventController.add(CallEvent.error);
        },
      ),
    );

    await _engine.enableAudio();
    _isInitialized = true;
  }

  Future<bool> joinCall({required String channelName}) async {
    if (!_isInitialized) await init();

    try {
      debugPrint("⏳ Requesting Agora Token for channel: $channelName");
      
      // Request Secure Token from your Node.js backend
      final response = await ApiClient().post('/api/agora/token', {
        'channelName': channelName,
      });

      // ✅ THE FIX: Unwrap the response if it is nested inside a 'data' object
      final responseData = response['data'] ?? response;

      if (responseData['token'] != null) {
        String token = responseData['token'];

        // Join the actual voice channel
        await _engine.joinChannel(
          token: token,
          channelId: channelName,
          uid: 0,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileCommunication,
          ),
        );
        return true;
      } else {
        debugPrint("❌ Token missing in backend response: $response");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error joining Agora call: $e");
      return false;
    }
  }

  Future<void> leaveCall() async {
    if (isJoined) {
      await _engine.leaveChannel();
      isJoined = false;
    }
  }

  Future<void> toggleMute(bool isMuted) async {
    if (_isInitialized) await _engine.muteLocalAudioStream(isMuted);
  }

  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    if (_isInitialized) await _engine.setEnableSpeakerphone(isSpeakerOn);
  }
}