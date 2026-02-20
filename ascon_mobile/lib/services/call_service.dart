import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ascon_mobile/services/api_client.dart';

enum CallEvent { ringing, connected, callEnded, error, userJoined, userOffline }

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  late RtcEngine _engine;
  bool _isInitialized = false;
  bool isJoined = false;
  
  // ✅ Track multiple UIDs for Group Video Calls
  Set<int> remoteUids = {}; 

  final _callEventController = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get callEvents => _callEventController.stream;

  // ✅ Expose engine for Video Rendering in UI
  RtcEngine get engine => _engine; 

  Future<void> init() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      // ✅ Added Camera Permission
      await [Permission.microphone, Permission.camera].request();
    }

    String appId = dotenv.env['AGORA_APP_ID'] ?? '';
    if (appId.isEmpty) {
      debugPrint("❌ Agora App ID is missing from env.txt");
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        logConfig: const LogConfig(level: LogLevel.logLevelError),
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ Agora Joined Channel: ${connection.channelId}");
          isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("📞 Remote user answered! UID: $remoteUid");
          remoteUids.add(remoteUid); // ✅ Save their ID to show their video
          _callEventController.add(CallEvent.connected);
          _callEventController.add(CallEvent.userJoined);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("📞 Remote user left! UID: $remoteUid");
          remoteUids.remove(remoteUid); // ✅ Remove their video
          _callEventController.add(CallEvent.callEnded);
          _callEventController.add(CallEvent.userOffline);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora Error: $err - $msg");
          _callEventController.add(CallEvent.error);
        },
      ),
    );

    await _engine.enableAudio();
    await _engine.enableVideo(); // ✅ Enable Video Module
    _isInitialized = true;
  }

  Future<bool> joinCall({required String channelName, bool isVideo = false}) async {
    if (!_isInitialized) await init();

    try {
      final response = await ApiClient().post('/api/agora/token', {'channelName': channelName});
      final responseData = response['data'] ?? response;

      if (responseData['token'] != null) {
        String token = responseData['token'];

        // ✅ Start local camera preview if it's a video call
        if (isVideo) {
           await _engine.startPreview();
        }

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
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> leaveCall() async {
    if (isJoined) {
      await _engine.stopPreview(); // ✅ Stop camera
      await _engine.leaveChannel();
      remoteUids.clear(); // ✅ Clear video grid
      isJoined = false;
    }
  }

  Future<void> toggleMute(bool isMuted) async {
    if (_isInitialized) await _engine.muteLocalAudioStream(isMuted);
  }

  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    if (_isInitialized) await _engine.setEnableSpeakerphone(isSpeakerOn);
  }

  // ✅ New Video Methods
  Future<void> toggleVideo(bool isVideoOff) async {
    if (_isInitialized) {
      await _engine.muteLocalVideoStream(isVideoOff);
    }
  }

  Future<void> switchCamera() async {
    if (_isInitialized) {
      await _engine.switchCamera();
    }
  }
}