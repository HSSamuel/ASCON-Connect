import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'socket_service.dart';

class CallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  final _socket = SocketService().socket;

  /// ✅ DYNAMIC ICE CONFIGURATION
  /// Uses public STUN servers + Your Metered.ca TURN servers
  Future<Map<String, dynamic>> _getIceServers() async {
    // 1. Default Public STUN Servers (Always included)
    List<Map<String, dynamic>> iceServers = [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];

    // 2. Add TURN Servers from Environment
    final String? turnUrlRaw = dotenv.env['TURN_URL'];
    final String? turnUser = dotenv.env['TURN_USERNAME'];
    final String? turnPass = dotenv.env['TURN_PASSWORD'];

    if (turnUrlRaw != null && turnUrlRaw.isNotEmpty && 
        turnUser != null && turnUser.isNotEmpty && 
        turnPass != null && turnPass.isNotEmpty) {
      
      // ✅ Split comma-separated URLs to support TCP/UDP fallbacks
      List<String> turnUrls = turnUrlRaw.split(',').map((e) => e.trim()).toList();

      iceServers.add({
        'urls': turnUrls, 
        'username': turnUser,
        'credential': turnPass,
      });
    }

    return {
      'iceServers': iceServers,
      // 'all' allows WebRTC to test both direct (P2P) and Relay (TURN) connections
      'iceTransportPolicy': 'all', 
    };
  }

  /// 1. Initialize & Start Call
  Future<void> startCall(String receiverId) async {
    if (_socket == null) return;

    // ✅ Get Config with TURN support
    final configuration = await _getIceServers();
    _peerConnection = await createPeerConnection(configuration);

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

    // ✅ Get Config with TURN support
    final configuration = await _getIceServers();
    _peerConnection = await createPeerConnection(configuration);

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