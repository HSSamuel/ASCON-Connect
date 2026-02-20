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

    if (!kIsWeb) {
      await [Permission.microphone].request();
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
        logConfig: const LogConfig(
          level: LogLevel.logLevelError, 
        ),
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
          _callEventController.add(CallEvent.connected);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("📞 Remote user left! UID: $remoteUid");
          _callEventController.add(CallEvent.callEnded);
          // ✅ FIXED: Removed leaveCall() here so group calls don't drop when one person leaves
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
      final response = await ApiClient().post('/api/agora/token', {
        'channelName': channelName,
      });

      final responseData = response['data'] ?? response;

      if (responseData['token'] != null) {
        String token = responseData['token'];

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