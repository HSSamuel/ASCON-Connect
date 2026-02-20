import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:agora_rtc_engine/agora_rtc_engine.dart'; // ✅ Added for Video Views
import '../services/call_service.dart';
import '../services/socket_service.dart';

class CallScreen extends StatefulWidget {
  final bool isGroupCall;          
  final bool isVideoCall;          // ✅ NEW: Video flag
  final List<String>? targetIds;   
  final String remoteName;
  final String? remoteId;          
  final String channelName; 
  final String? remoteAvatar; 
  final bool isIncoming; 
  final String? currentUserName;   
  final String? currentUserAvatar; 

  const CallScreen({
    super.key, 
    this.isGroupCall = false, 
    this.isVideoCall = false,      // ✅ NEW: Defaults to false (Audio)
    this.targetIds,
    required this.remoteName, 
    this.remoteId,
    required this.channelName,
    this.remoteAvatar,
    this.isIncoming = false, 
    this.currentUserName,     
    this.currentUserAvatar,   
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final CallService _callService = CallService();
  final SocketService _socketService = SocketService();
  final AudioPlayer _audioPlayer = AudioPlayer(); 
  
  String _status = "Connecting...";
  bool _isMuted = false;
  bool _isVideoOff = false; // ✅ Track Video State
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  bool _hasAccepted = false;
  int _activeGroupUsers = 0; 

  StreamSubscription<CallEvent>? _listener;
  StreamSubscription<Map<String, dynamic>>? _socketListener;
  
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    // Auto-enable speaker for video calls
    if (widget.isVideoCall) _isSpeakerOn = true; 

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat(reverse: true);

    _listenToEvents();

    if (widget.isIncoming) {
      _status = widget.isVideoCall ? "Incoming Video Call..." : "Incoming Call...";
      _pulseController.repeat(reverse: true);
      _playRingtone(); 
    } else {
      _status = "Ringing...";
      _startOutgoingCall();
      _playDialingSound(); 
    }
  }

  // ... (Keep _playRingtone, _playDialingSound, _stopAudio exact same) ...
  void _playRingtone() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
  }

  void _playDialingSound() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/dialing.mp3'));
  }

  void _stopAudio() async {
    await _audioPlayer.stop();
  }

  void _startOutgoingCall() async {
    bool success = await _callService.joinCall(channelName: widget.channelName, isVideo: widget.isVideoCall); // ✅ Passed isVideo flag
    
    if (success) {
      if (widget.isVideoCall) _callService.toggleSpeaker(true); // Force speaker

      Map<String, dynamic> callerPayload = {
        'callerName': widget.currentUserName ?? "Unknown User", 
        'callerAvatar': widget.currentUserAvatar,
        'isGroupCall': widget.isGroupCall,
        'isVideoCall': widget.isVideoCall, // ✅ Send Video Flag securely to receiver
        'groupName': widget.remoteName 
      };

      if (widget.isGroupCall && widget.targetIds != null) {
        for (String target in widget.targetIds!) {
          _socketService.initiateCall(target, widget.channelName, callerPayload);
        }
      } else if (widget.remoteId != null) {
        _socketService.initiateCall(widget.remoteId!, widget.channelName, callerPayload);
      }
    } else {
      _endCallUI("Call Failed");
    }
  }

  void _acceptIncomingCall() async {
    setState(() {
      _hasAccepted = true;
      _status = "Connecting...";
    });
    
    _stopAudio(); 

    if (widget.remoteId != null) {
      _socketService.answerCall(widget.remoteId!, widget.channelName);
    }
    
    await _callService.joinCall(channelName: widget.channelName, isVideo: widget.isVideoCall);
    if (widget.isVideoCall) _callService.toggleSpeaker(true); 
  }

  void _listenToEvents() {
    _listener = _callService.callEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event == CallEvent.connected || event == CallEvent.userJoined || event == CallEvent.userOffline) {
          if (widget.isGroupCall) {
            _activeGroupUsers = _callService.remoteUids.length;
            _status = "Connected ($_activeGroupUsers joined)";
          } else {
            _status = "Connected";
          }
          
          if (!_isConnected) {
            _isConnected = true;
            _stopAudio(); 
            _pulseController.stop();
            _startTimer();
          }
        } else if (event == CallEvent.callEnded) {
          if (widget.isGroupCall) {
            _activeGroupUsers = _callService.remoteUids.length;
            if (_activeGroupUsers == 0) _status = "Waiting for others...";
          } else {
            _endCallUI("Call Ended");
          }
        }
      });
    });

    _socketListener = _socketService.callEvents.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'ended' && event['data']['channelName'] == widget.channelName) {
        if (widget.isGroupCall) {
           if (widget.isIncoming && !_hasAccepted && event['data']['callerId'] == widget.remoteId) {
             _endCallUI("Call Ended");
           }
        } else {
           _endCallUI("Call Ended");
        }
      } else if (event['type'] == 'answered' && event['data']['channelName'] == widget.channelName) {
        if (!widget.isGroupCall) {
          setState(() => _status = "Connecting Audio...");
        }
      }
    });
  }

  void _endCallUI(String message) {
    setState(() => _status = message);
    _stopAudio(); 
    _stopTimer();
    _pulseController.stop();
    _callService.leaveCall();
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  void _startTimer() {
    if (_callTimer != null && _callTimer!.isActive) return;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  void _stopTimer() => _callTimer?.cancel();

  String get _formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(_callDuration.inMinutes.remainder(60));
    String seconds = twoDigits(_callDuration.inSeconds.remainder(60));
    return _callDuration.inHours > 0 ? "${twoDigits(_callDuration.inHours)}:$minutes:$seconds" : "$minutes:$seconds";
  }

  @override
  void dispose() {
    _stopAudio(); 
    _audioPlayer.dispose();
    _listener?.cancel();
    _socketListener?.cancel();
    _stopTimer();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack( // ✅ Used Stack to place Video under Controls
        children: [
          // ✅ 1. BACKGROUND (Video or Gradient)
          if (widget.isVideoCall && _isConnected)
            _buildVideoGrid()
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F3621), Colors.black],
                ),
              ),
            ),

          // ✅ 2. FOREGROUND (UI & Controls)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!widget.isVideoCall || !_isConnected) const Spacer(flex: 2),
                
                if (!widget.isVideoCall || !_isConnected)
                  _buildPulsingAvatar(),
                
                const SizedBox(height: 30),
                
                if (!widget.isVideoCall || !_isConnected)
                  if (widget.isGroupCall)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text(widget.isVideoCall ? "GROUP VIDEO CALL" : "GROUP CALL", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),

                if (!widget.isVideoCall || !_isConnected)
                  Text(
                    widget.remoteName,
                    style: GoogleFonts.lato(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, shadows: [const Shadow(color: Colors.black, blurRadius: 10)]),
                    textAlign: TextAlign.center,
                  ),
                
                const SizedBox(height: 12),
                
                if (!widget.isVideoCall || !_isConnected || widget.isGroupCall)
                  Text(
                    _isConnected ? _formattedDuration : _status,
                    style: GoogleFonts.lato(color: Colors.white70, fontSize: _isConnected ? 20 : 16, shadows: [const Shadow(color: Colors.black, blurRadius: 10)]),
                  ),

                const Spacer(flex: 3),
                
                // ✅ CONTROLS UI
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: widget.isIncoming && !_hasAccepted 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionCircle(Icons.call_end, Colors.redAccent, () {
                          if (widget.remoteId != null) _socketService.endCall(widget.remoteId!, widget.channelName);
                          _endCallUI("Declined");
                        }),
                        _buildActionCircle(widget.isVideoCall ? Icons.videocam : Icons.call, Colors.green, _acceptIncomingCall),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isVideoCall) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSmallBtn(Icons.flip_camera_ios, "Flip", () => _callService.switchCamera()),
                              const SizedBox(width: 40),
                              _buildSmallBtn(_isVideoOff ? Icons.videocam_off : Icons.videocam, _isVideoOff ? "Video Off" : "Video On", () {
                                setState(() => _isVideoOff = !_isVideoOff);
                                _callService.toggleVideo(_isVideoOff);
                              }, isActive: !_isVideoOff),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        Row( 
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              label: "Mute",
                              isActive: _isMuted,
                              onTap: () {
                                setState(() => _isMuted = !_isMuted);
                                _callService.toggleMute(_isMuted);
                              },
                            ),
                            _buildActionCircle(Icons.call_end, Colors.redAccent, () {
                              if (widget.isGroupCall && widget.targetIds != null && !widget.isIncoming) {
                                 for(String target in widget.targetIds!) _socketService.endCall(target, widget.channelName);
                              } else if (widget.remoteId != null) {
                                 _socketService.endCall(widget.remoteId!, widget.channelName);
                              }
                              _endCallUI("Call Ended");
                            }),
                            _buildControlButton(
                              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                              label: "Speaker",
                              isActive: _isSpeakerOn,
                              onTap: () {
                                setState(() => _isSpeakerOn = !_isSpeakerOn);
                                _callService.toggleSpeaker(_isSpeakerOn);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                ),
              ],
            ),
          ),

          // ✅ 3. LOCAL VIDEO (Picture-in-Picture)
          if (widget.isVideoCall && _isConnected && !_isVideoOff)
             Positioned(
               right: 16,
               top: MediaQuery.of(context).padding.top + 20,
               child: Container(
                 width: 110, height: 160,
                 decoration: BoxDecoration(
                   color: Colors.black,
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: Colors.white24, width: 2),
                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]
                 ),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(14),
                   child: AgoraVideoView(
                     controller: VideoViewController(
                       rtcEngine: _callService.engine,
                       canvas: const VideoCanvas(uid: 0), // 0 means local camera
                     ),
                   ),
                 ),
               ),
             )
        ],
      ),
    );
  }

  // ✅ HANDLES FULL SCREEN AND GRID FOR GROUP VIDEO
  Widget _buildVideoGrid() {
    List<int> uids = _callService.remoteUids.toList();

    if (uids.isEmpty) {
      return const Center(child: Text("Waiting for others to join...", style: TextStyle(color: Colors.white)));
    }

    if (uids.length == 1) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _callService.engine,
          canvas: VideoCanvas(uid: uids[0]),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }

    // Wrap in a GridView if more than 1 remote user
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: uids.length > 2 ? 2 : 1,
        childAspectRatio: uids.length > 2 ? 0.8 : 1.5,
      ),
      itemCount: uids.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.all(2),
          color: Colors.black,
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _callService.engine,
              canvas: VideoCanvas(uid: uids[index]),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          ),
        );
      },
    );
  }

  // ... (Keep _buildPulsingAvatar, _buildActionCircle, _buildControlButton exact same) ...
  Widget _buildPulsingAvatar() {
    final bool hasValidAvatar = widget.remoteAvatar != null && widget.remoteAvatar!.isNotEmpty;
    Widget avatar = CircleAvatar(
      radius: 65,
      backgroundColor: Colors.white24,
      backgroundImage: hasValidAvatar ? NetworkImage(widget.remoteAvatar!) : null,
      child: !hasValidAvatar ? Text(widget.remoteName.isNotEmpty ? widget.remoteName[0].toUpperCase() : "?", style: const TextStyle(fontSize: 48, color: Colors.white)) : null,
    );
    if (_isConnected) return avatar;

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
          child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1))),
        ),
        avatar,
      ],
    );
  }

  Widget _buildActionCircle(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 15)]),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontSize: 14)),
      ],
    );
  }

  Widget _buildSmallBtn(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isActive ? Colors.white : Colors.white24, shape: BoxShape.circle),
            child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}