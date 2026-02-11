import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:permission_handler/permission_handler.dart'; 
import 'socket_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO; // Added for type definition

class CallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  // ✅ FIX: Use a getter to access the current active socket instance.
  // Previously: final _socket = SocketService().socket; (This caused the bug)
  IO.Socket? get _socket => SocketService().socket;

  // Request Permissions Helper
  Future<bool> _checkPermissions() async {
    var status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<Map<String, dynamic>> _getIceServers() async {
    List<Map<String, dynamic>> iceServers = [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];

    final String? turnUrlRaw = dotenv.env['TURN_URL'];
    final String? turnUser = dotenv.env['TURN_USERNAME'];
    final String? turnPass = dotenv.env['TURN_PASSWORD'];

    if (turnUrlRaw != null && turnUrlRaw.isNotEmpty && 
        turnUser != null && turnUser.isNotEmpty && 
        turnPass != null && turnPass.isNotEmpty) {
      
      List<String> turnUrls = turnUrlRaw.split(',').map((e) => e.trim()).toList();
      iceServers.add({
        'urls': turnUrls, 
        'username': turnUser,
        'credential': turnPass,
      });
    }

    return {
      'iceServers': iceServers,
      'iceTransportPolicy': 'all', 
    };
  }

  Future<void> startCall(String receiverId) async {
    if (_socket == null) return;
    if (!await _checkPermissions()) throw Exception("Microphone permission denied");

    final configuration = await _getIceServers();
    _peerConnection = await createPeerConnection(configuration);

    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('ice_candidate', {
        'to': receiverId,
        'candidate': candidate.toMap(),
      });
    };

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socket?.emit('call_user', {
      'userToCall': receiverId,
      'offer': offer.toMap(),
    });
  }

  Future<void> answerCall(Map<String, dynamic> offer, String callerId) async {
    if (_socket == null) return;
    if (!await _checkPermissions()) throw Exception("Microphone permission denied");

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

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket?.emit('make_answer', {
      'to': callerId,
      'answer': answer.toMap(),
    });
  }

  Future<void> handleAnswer(Map<String, dynamic> answer) async {
    if (_peerConnection != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    }
  }

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

  // Toggle Mute
  void toggleMute(bool mute) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !mute;
      });
    }
  }

  // Toggle Speaker
  void toggleSpeaker(bool enable) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enableSpeakerphone(enable);
      });
    }
  }

  void endCall() {
    _localStream?.dispose();
    _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}