import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ Import dotenv
import '../services/socket_service.dart';

enum CallState {
  idle,
  calling,
  incoming,
  connected,
}

class CallService {
  // Singleton
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
  
  // Call State Streams
  final _callStateController = StreamController<CallState>.broadcast();
  Stream<CallState> get callStateStream => _callStateController.stream;

  final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;

  final _localStreamController = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get localStreamStream => _localStreamController.stream;

  void dispose() {
    _closePeerConnection();
    _callStateController.close();
    _remoteStreamController.close();
    _localStreamController.close();
  }

  // --- 1. START CALL (Caller) ---

  Future<void> startCall(String remoteUserId, {bool video = false}) async {
    if (_isCallActive) return;
    
    // ✅ Check Permissions first
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _checkPermissions();
    }

    _remoteId = remoteUserId;
    _isCallActive = true;
    _isRemoteDescriptionSet = false; // Reset
    _candidateQueue.clear();

    _callStateController.add(CallState.calling);

    await _createPeerConnection();
    if (_peerConnection == null) return;

    await _getUserMedia(video: video);
    if (_peerConnection == null) return;

    // Force audio routing to earpiece (default for calls)
    await toggleSpeaker(false);

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
    // ✅ Check Permissions first
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _checkPermissions();
    }

    _remoteId = callerId;
    _isCallActive = true;
    _isRemoteDescriptionSet = false; // Reset
    _candidateQueue.clear();
    
    _callStateController.add(CallState.connected);

    await _createPeerConnection();
    if (_peerConnection == null) return;

    // Force audio routing to earpiece
    await toggleSpeaker(false);

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    _isRemoteDescriptionSet = true; // ✅ Mark as ready
    _processCandidateQueue();       // ✅ Process any buffered candidates

    await _getUserMedia(video: video);
    if (_peerConnection == null) return;

    RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });

    if (_peerConnection == null) return;

    await _peerConnection!.setLocalDescription(answer);

    // ✅ FIX: Emit single 'make_answer' event with both answer AND callLogId
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
    _isRemoteDescriptionSet = true; // ✅ Mark as ready
    _processCandidateQueue();       // ✅ Process any buffered candidates

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
      // ✅ Buffer if remote description is not set yet
      _candidateQueue.add(candidate);
    }
  }

  void _processCandidateQueue() async {
    for (var candidate in _candidateQueue) {
      await _peerConnection?.addCandidate(candidate);
    }
    _candidateQueue.clear();
  }

  // --- 5. UTILS & CONTROLS ---

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      // Android 12+ needs BluetoothConnect for headsets
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.bluetoothConnect, 
      ].request();
      
      if (statuses[Permission.microphone]!.isDenied) {
        throw Exception('Microphone permission required');
      }
    }
  }

  Future<void> _createPeerConnection() async {
    // ✅ Load from .env
    final String turnUrlString = dotenv.env['TURN_URL'] ?? "";
    final String turnUsername = dotenv.env['TURN_USERNAME'] ?? "";
    final String turnPassword = dotenv.env['TURN_PASSWORD'] ?? "";

    // ✅ Split the comma-separated URL string from Metered
    // e.g. "turn:global.relay.metered.ca:80,turn:global..." -> ["turn:...", "turn:..."]
    List<String> turnUrls = turnUrlString.isNotEmpty 
        ? turnUrlString.split(',') 
        : [];

    Map<String, dynamic> configuration = {
      "iceServers": [
        // 1. Google STUN (Always keep as fallback/initial check)
        {"urls": "stun:stun.l.google.com:19302"},
        
        // 2. Metered.ca TURN (Loaded dynamically from .env)
        if (turnUrls.isNotEmpty)
          {
            "urls": turnUrls,
            "username": turnUsername,
            "credential": turnPassword
          }
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
        // Explicitly enable remote audio tracks
        _remoteStream!.getAudioTracks().forEach((track) {
          track.enabled = true;
        });
        _remoteStreamController.add(_remoteStream);
      }
    };
    
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };
  }

  Future<void> _getUserMedia({bool video = false}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true, 
      'video': video ? {'facingMode': 'user'} : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStreamController.add(_localStream);
      
      // Explicitly enable local audio tracks
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = true; 
      });

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
    try {
      await Helper.setSpeakerphoneOn(enable);
    } catch (e) {
      debugPrint("Error toggling speaker: $e");
    }
  }

  Future<void> toggleMute(bool mute) async {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !mute;
      });
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
    // ✅ Fix: release hardware lock properly
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
  }
}