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
    
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _checkPermissions();
    }

    _remoteId = remoteUserId;
    _isCallActive = true;
    _isRemoteDescriptionSet = false;
    _candidateQueue.clear();

    _callStateController.add(CallState.calling);

    await _createPeerConnection();
    if (_peerConnection == null) return;

    await _getUserMedia(video: video);
    if (_peerConnection == null) return;

    // ✅ FIX: Allow stream to initialize before forcing earpiece
    await Future.delayed(const Duration(milliseconds: 500));
    await toggleSpeaker(false); // Default to Earpiece

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
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _checkPermissions();
    }

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

    // ✅ FIX: Force audio routing AFTER getting media
    await Future.delayed(const Duration(milliseconds: 500));
    await toggleSpeaker(false);

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

  // --- 5. UTILS & CONTROLS ---

Future<void> _checkPermissions() async {
    if (kIsWeb) return;

    // ✅ WINDOWS FIX: Windows usually manages permissions at the OS level 
    // or via the runner. Explicit requests often fail or aren't needed the same way.
    if (Platform.isAndroid || Platform.isIOS) { 
      var status = await Permission.microphone.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.microphone.request();
      }

      if (status.isDenied) {
        throw Exception('Microphone permission required');
      }
      
      if (Platform.isAndroid) {
        await Permission.bluetoothConnect.request();
      }
    }
  }

  Future<void> _createPeerConnection() async {
    final String turnUrlString = dotenv.env['TURN_URL'] ?? "";
    final String turnUsername = dotenv.env['TURN_USERNAME'] ?? "";
    final String turnPassword = dotenv.env['TURN_PASSWORD'] ?? "";

    List<String> turnUrls = turnUrlString.isNotEmpty 
        ? turnUrlString.split(',') 
        : [];

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
        
        // ✅ FIX: Ensure audio output is routed to speaker/earpiece immediately upon connection
        if (!kIsWeb) {
          Helper.setSpeakerphoneOn(false); 
        }
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
    // ✅ FIX: Enhanced Audio Constraints for better call quality
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
    
    // ✅ WINDOWS FIX: Skip this logic on Desktop. 
    // PCs handle audio routing automatically (Headphones/Speakers).
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

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
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
  }
}