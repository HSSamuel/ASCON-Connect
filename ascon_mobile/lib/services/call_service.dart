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
  // Singleton Pattern
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _remoteId;
  bool _isCallActive = false;
  
  // Buffering for ICE candidates
  bool _isRemoteDescriptionSet = false;
  final List<RTCIceCandidate> _candidateQueue = [];
  
  final _callStateController = StreamController<CallState>.broadcast();
  Stream<CallState> get callStateStream => _callStateController.stream;

  final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;

  final _localStreamController = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get localStreamStream => _localStreamController.stream;

  void dispose() {
    _closePeerConnection();
  }

  // ✅ ADDED: Explicit Audio Setup to ensure Communication Mode
  // This is critical for Android to prioritize the mic correctly.
  Future<void> _configureAudioSession() async {
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    
    try {
      // 1. Force Speaker OFF by default (Earpiece)
      // 2. This helper method in flutter_webrtc triggers AudioManager.setMode(MODE_IN_COMMUNICATION) on Android
      await Helper.setSpeakerphoneOn(false);
    } catch (e) {
      debugPrint("⚠️ Audio Config Error: $e");
    }
  }

  // --- 1. START CALL (Caller) ---
  Future<void> startCall(String remoteUserId, {bool video = false}) async {
    if (_isCallActive) return;
    
    await _checkPermissions();

    // ✅ Configure Audio Session BEFORE creating connections
    await _configureAudioSession();

    _remoteId = remoteUserId;
    _isCallActive = true;
    _isRemoteDescriptionSet = false;
    _candidateQueue.clear();

    _callStateController.add(CallState.calling);

    await _createPeerConnection();
    if (_peerConnection == null) return;

    await _getUserMedia(video: video);
    if (_peerConnection == null) return;

    // Apply video-specific audio routing (Speaker for video, Earpiece for audio)
    await toggleSpeaker(video); 

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

  // --- 2. ANSWER CALL (Receiver) ---
  Future<void> answerCall(Map<String, dynamic> offer, String callerId, String? callLogId, {bool video = false}) async {
    await _checkPermissions();

    // ✅ Configure Audio Session BEFORE creating connections
    await _configureAudioSession();

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

    // Apply video-specific audio routing
    await toggleSpeaker(video);

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

  // --- 3. HANDLE ANSWER (Caller) ---
  Future<void> handleAnswer(dynamic answerData) async {
    if (_peerConnection == null) return;
    
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answerData['sdp'], answerData['type']),
    );
    _isRemoteDescriptionSet = true;
    _processCandidateQueue();

    _callStateController.add(CallState.connected);
  }

  // --- 4. HANDLE ICE CANDIDATES (Both) ---
  Future<void> handleIceCandidate(dynamic candidateData) async {
    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
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

  // --- 5. SETUP PEER CONNECTION (ROBUST) ---
  Future<void> _createPeerConnection() async {
    final String rawTurnUrl = dotenv.env['TURN_URL'] ?? "";
    final String turnUsername = dotenv.env['TURN_USERNAME'] ?? "";
    final String turnPassword = dotenv.env['TURN_PASSWORD'] ?? "";

    List<String> turnUrls = [];
    if (rawTurnUrl.isNotEmpty) {
      turnUrls = rawTurnUrl.split(',')
          .map((e) => e.trim()) 
          .where((e) => e.isNotEmpty)
          .toList();
    }

    Map<String, dynamic> configuration = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
        if (turnUrls.isNotEmpty)
          {
            "urls": turnUrls,
            "username": turnUsername,
            "credential": turnPassword
          }
      ],
      "iceTransportPolicy": "all",
      "sdpSemantics": "unified-plan",
      "iceCandidatePoolSize": 10,
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
        _remoteStream!.getAudioTracks().forEach((track) {
          track.enabled = true;
        });
        _remoteStreamController.add(_remoteStream);
        
        // ✅ REMOVED: Auto-switching speaker here is dangerous (Race Condition)
        // We now handle initial audio routing in _configureAudioSession()
        // and toggleSpeaker() inside startCall/answerCall.
      }
    };
    
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint("WebRTC Connection State: $state");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };
    
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint("ICE Connection State: $state");
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
         endCall();
      }
    };
  }

  // --- UTILS ---

  Future<void> _checkPermissions() async {
    if (kIsWeb) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    var micStatus = await Permission.microphone.status;
    if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
      micStatus = await Permission.microphone.request();
    }
    if (micStatus.isDenied) throw Exception('Microphone permission required');
    
    if (Platform.isAndroid) {
      // ✅ Fix: Request Bluetooth Connect to allow headsets
      await Permission.bluetoothConnect.request();
    }
  }

  Future<void> _getUserMedia({bool video = false}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      }, 
      'video': video ? {'facingMode': 'user'} : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
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
      await Helper.setSpeakerphoneOn(enable);
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