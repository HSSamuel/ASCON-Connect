import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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
    
    _remoteId = remoteUserId;
    _isCallActive = true;
    _callStateController.add(CallState.calling);

    await _createPeerConnection();
    // ✅ SAFETY CHECK 1: Call might have ended while creating peer connection
    if (_peerConnection == null) return;

    await _getUserMedia(video: video);
    // ✅ SAFETY CHECK 2: Call might have ended while getting media
    if (_peerConnection == null) return;

    // Force audio routing to earpiece (default for calls)
    if (!kIsWeb) {
      try {
        Helper.setSpeakerphoneOn(false);
      } catch (e) {
        debugPrint("Error setting initial audio route: $e");
      }
    }

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });

    // ✅ SAFETY CHECK 3: Call might have ended while creating offer
    if (_peerConnection == null) return;

    await _peerConnection!.setLocalDescription(offer);

    SocketService().socket?.emit('call_user', {
      'userToCall': remoteUserId,
      'offer': offer.toMap(),
    });
  }

  // --- 2. ANSWER CALL (Receiver) ---
  Future<void> answerCall(Map<String, dynamic> offer, String callerId, {bool video = false}) async {
    _remoteId = callerId;
    _isCallActive = true;
    _callStateController.add(CallState.connected);

    await _createPeerConnection();
    if (_peerConnection == null) return;

    // Force audio routing to earpiece
    if (!kIsWeb) {
      try {
        Helper.setSpeakerphoneOn(false);
      } catch (e) {
        debugPrint("Error setting initial audio route: $e");
      }
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

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
    });
  }

  // --- 3. HANDLE ANSWER (Caller) ---
  Future<void> handleAnswer(dynamic answerData) async {
    if (_peerConnection == null) return;
    
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answerData['sdp'], answerData['type']),
    );
    _callStateController.add(CallState.connected);
  }

  // --- 4. HANDLE ICE CANDIDATES (Both) ---
  Future<void> handleIceCandidate(dynamic candidateData) async {
    if (_peerConnection != null) {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        ),
      );
    }
  }

  // --- 5. UTILS & CONTROLS ---

  Future<void> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ]
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
  }

  void _closePeerConnection() {
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
  }
}