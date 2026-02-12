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
    await _getUserMedia(video: video);

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });

    await _peerConnection!.setLocalDescription(offer);

    // ✅ FIXED: Null-safe access to socket
    SocketService().socket?.emit('call_user', {
      'userToCall': remoteUserId,
      'offer': offer.toMap(),
    });
  }

  // --- 2. ANSWER CALL (Receiver) ---
  // ✅ ADDED: This matches the method called in CallScreen
  Future<void> answerCall(Map<String, dynamic> offer, String callerId, {bool video = false}) async {
    _remoteId = callerId;
    _isCallActive = true;
    _callStateController.add(CallState.connected);

    await _createPeerConnection();
    
    // Set Remote Description (Offer from Caller)
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    // Get Local Media
    await _getUserMedia(video: video);

    // Create Answer
    RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });

    await _peerConnection!.setLocalDescription(answer);

    // Send Answer back to Caller
    // ✅ FIXED: Null-safe access to socket
    SocketService().socket?.emit('make_answer', {
      'to': _remoteId,
      'answer': answer.toMap(),
    });
  }

  // --- 3. HANDLE ANSWER (Caller) ---
  // ✅ ADDED: Public method called by CallScreen when 'answer_made' event arrives
  Future<void> handleAnswer(dynamic answerData) async {
    if (_peerConnection == null) return;
    
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answerData['sdp'], answerData['type']),
    );
    _callStateController.add(CallState.connected);
  }

  // --- 4. HANDLE ICE CANDIDATES (Both) ---
  // ✅ ADDED: Public method called by CallScreen when 'ice_candidate' event arrives
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
        // ✅ FIXED: Null-safe access
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
    
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }
  
  Future<void> toggleSpeaker(bool enable) async {
    if (kIsWeb) return; 

    try {
      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          track.enableSpeakerphone(enable);
        });
      }
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