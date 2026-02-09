import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class CallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  final _socket = SocketService().socket;

  // STUN Servers (Google's public ones)
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  /// 1. Initialize & Start Call
  Future<void> startCall(String receiverId) async {
    if (_socket == null) return;

    // Create Connection
    _peerConnection = await createPeerConnection(_iceServers);

    // Get Microphone
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle ICE Candidates
    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('ice_candidate', {
        'to': receiverId,
        'candidate': candidate.toMap(),
      });
    };

    // Create Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Send Offer via Socket
    _socket?.emit('call_user', {
      'userToCall': receiverId,
      'offer': offer.toMap(),
    });
  }

  /// 2. Answer an Incoming Call
  Future<void> answerCall(Map<String, dynamic> offer, String callerId) async {
    if (_socket == null) return;

    _peerConnection = await createPeerConnection(_iceServers);

    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('ice_candidate', {
        'to': callerId,
        'candidate': candidate.toMap(),
      });
    };

    // Set Remote Description (The Offer)
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    // Create Answer
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Send Answer
    _socket?.emit('make_answer', {
      'to': callerId,
      'answer': answer.toMap(),
    });
  }

  /// 3. Handle Answer from the other side
  Future<void> handleAnswer(Map<String, dynamic> answer) async {
    if (_peerConnection != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    }
  }

  /// 4. Handle ICE Candidate
  Future<void> handleIceCandidate(Map<String, dynamic> candidate) async {
    if (_peerConnection != null) {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
    }
  }

  /// 5. End Call
  void endCall() {
    _localStream?.dispose();
    _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}