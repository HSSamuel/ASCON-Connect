import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/socket_service.dart';

enum CallState {
  idle,
  calling,
  incoming,
  connected,
}

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _remoteId;
  bool _isCallActive = false;
  bool _isSpeakerOn = false; 
  
  bool _isRemoteDescriptionSet = false;
  final List<RTCIceCandidate> _candidateQueue = [];
  
  // ✅ FIX: Broadcast streams are kept open for the app's lifetime
  final _callStateController = StreamController<CallState>.broadcast();
  Stream<CallState> get callStateStream => _callStateController.stream;

  final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;

  final _localStreamController = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get localStreamStream => _localStreamController.stream;

  // ✅ FIX: "reset" instead of "dispose" to keep streams alive
  void reset() {
    _closePeerConnection();
    if (!_callStateController.isClosed) {
      // Optional: notify listeners that call is reset, but don't close stream
    }
  }

  Future<void> ensureAudioSession({bool video = false}) async {
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    
    try {
      _isSpeakerOn = video;
      await Future.delayed(const Duration(milliseconds: 200));
      await toggleSpeaker(_isSpeakerOn);
    } catch (e) {
      debugPrint("⚠️ Audio Config Error: $e");
    }
  }

  Future<void> startCall(String remoteUserId, {bool video = false}) async {
    if (_isCallActive) return;
    await _checkPermissions();
    
    _isSpeakerOn = video;
    _remoteId = remoteUserId;
    _isCallActive = true;
    _isRemoteDescriptionSet = false;
    _candidateQueue.clear();

    _callStateController.add(CallState.calling);

    await _createPeerConnection();
    if (_peerConnection == null) return;

    await _getUserMedia(video: video);
    if (_peerConnection == null) return;

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });

    if (_peerConnection == null) return;

    await _peerConnection!.setLocalDescription(offer);

    SocketService().socket?.emit('call_user', {
      'userToCall': remoteUserId,
      'offer': offer.toMap(),
    });
  }

  Future<void> answerCall(Map<String, dynamic> offer, String callerId, String? callLogId, {bool video = false}) async {
    await _checkPermissions();
    
    _isSpeakerOn = video;
    _remoteId = callerId;
    _isCallActive = true;
    _isRemoteDescriptionSet = false;
    _candidateQueue.clear();
    
    _callStateController.add(CallState.connected);

    await _createPeerConnection();
    if (_peerConnection == null) return;

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    _isRemoteDescriptionSet = true;
    _processCandidateQueue();

    await _getUserMedia(video: video);
    if (_peerConnection == null) return;

    RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });

    if (_peerConnection == null) return;

    await _peerConnection!.setLocalDescription(answer);

    SocketService().socket?.emit('make_answer', {
      'to': _remoteId,
      'answer': answer.toMap(),
      'callLogId': callLogId, 
    });
  }

  Future<void> handleAnswer(dynamic answerData) async {
    if (_peerConnection == null) return;
    
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answerData['sdp'], answerData['type']),
    );
    _isRemoteDescriptionSet = true;
    _processCandidateQueue();

    _callStateController.add(CallState.connected);
  }

  Future<void> handleIceCandidate(dynamic candidateData) async {
    // ✅ FIX: Safe Cast for Web Compatibility
    final Map<String, dynamic> data = Map<String, dynamic>.from(candidateData);

    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );

    if (_peerConnection != null && _isRemoteDescriptionSet) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _candidateQueue.add(candidate);
    }
  }

  void _processCandidateQueue() async {
    for (var candidate in _candidateQueue) {
      await _peerConnection?.addCandidate(candidate);
    }
    _candidateQueue.clear();
  }

  Future<void> _createPeerConnection() async {
    final String rawTurnUrl = dotenv.env['TURN_URL'] ?? "";
    final String turnUsername = dotenv.env['TURN_USERNAME'] ?? "";
    final String turnPassword = dotenv.env['TURN_PASSWORD'] ?? "";

    List<String> turnUrls = [];
    if (rawTurnUrl.isNotEmpty) {
      turnUrls = rawTurnUrl.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    Map<String, dynamic> configuration = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
        if (turnUrls.isNotEmpty)
          {"urls": turnUrls, "username": turnUsername, "credential": turnPassword}
      ],
      "iceTransportPolicy": "all",
      "sdpSemantics": "unified-plan",
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_remoteId != null) {
        SocketService().socket?.emit('ice_candidate', {
          'to': _remoteId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStream!.getAudioTracks().forEach((track) => track.enabled = true);
        _remoteStreamController.add(_remoteStream);
        ensureAudioSession(video: _isSpeakerOn);
      }
    };
    
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    var micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) micStatus = await Permission.microphone.request();
    if (micStatus.isDenied) throw Exception('Microphone permission required');
    if (Platform.isAndroid) await Permission.bluetoothConnect.request();
  }

  Future<void> _getUserMedia({bool video = false}) async {
    final Map<String, dynamic> constraints = {
      'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true}, 
      'video': video ? {'facingMode': 'user'} : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localStreamController.add(_localStream);
      _localStream!.getAudioTracks().forEach((track) => track.enabled = true);

      if (_peerConnection != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }
    } catch (e) {
      debugPrint("Error getting user media: $e");
    }
  }
  
  Future<void> toggleSpeaker(bool enable) async {
    if (kIsWeb) return; 
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    try {
      _isSpeakerOn = enable;
      // ✅ FIX: Real speaker implementation
      if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
        _localStream!.getAudioTracks()[0].enableSpeakerphone(enable);
      }
    } catch (e) {
      debugPrint("Error toggling speaker: $e");
    }
  }

  Future<void> toggleMute(bool mute) async {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) => track.enabled = !mute);
    }
  }

  void endCall() {
    _closePeerConnection();
    _callStateController.add(CallState.idle);
    _isCallActive = false;
    _remoteId = null;
    _candidateQueue.clear();
  }

  void _closePeerConnection() {
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
  }
}