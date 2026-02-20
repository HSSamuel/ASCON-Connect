import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart'; 
import '../services/call_service.dart';
import '../services/socket_service.dart';

class CallScreen extends StatefulWidget {
  final bool isGroupCall;          // ✅ Added for Group Logic
  final List<String>? targetIds;   // ✅ Added to ring multiple people
  final String remoteName;
  final String? remoteId;          // Nullable now (initiator doesn't need it for groups)
  final String channelName; 
  final String? remoteAvatar; 
  final bool isIncoming; 
  final String? currentUserName;   
  final String? currentUserAvatar; 

  const CallScreen({
    super.key, 
    this.isGroupCall = false, // defaults to false
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
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  bool _hasAccepted = false;
  int _activeGroupUsers = 0; // ✅ Tracks how many people are in the group call

  StreamSubscription<CallEvent>? _listener;
  StreamSubscription<Map<String, dynamic>>? _socketListener;
  
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat(reverse: true);

    _listenToEvents();

    if (widget.isIncoming) {
      _status = "Incoming Call...";
      _pulseController.repeat(reverse: true);
      _playRingtone(); 
    } else {
      _status = "Ringing...";
      _startOutgoingCall();
      _playDialingSound(); 
    }
  }

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
    bool success = await _callService.joinCall(channelName: widget.channelName);
    
    if (success) {
      // ✅ GROUP CALL LOOP
      if (widget.isGroupCall && widget.targetIds != null) {
        for (String target in widget.targetIds!) {
          _socketService.initiateCall(target, widget.channelName, {
            'callerName': widget.currentUserName ?? "Unknown User", 
            'callerAvatar': widget.currentUserAvatar,
            'isGroupCall': true,
            'groupName': widget.remoteName // Send group name so receivers see it
          });
        }
      } 
      // 1-ON-1 CALL
      else if (widget.remoteId != null) {
        _socketService.initiateCall(widget.remoteId!, widget.channelName, {
          'callerName': widget.currentUserName ?? "Unknown User", 
          'callerAvatar': widget.currentUserAvatar,
          'isGroupCall': false
        });
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
    
    await _callService.joinCall(channelName: widget.channelName);
  }

  void _listenToEvents() {
    _listener = _callService.callEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event == CallEvent.connected) {
          // ✅ Group logic vs 1-on-1 logic
          if (widget.isGroupCall) {
            _activeGroupUsers++;
            _status = "Connected ($_activeGroupUsers joined)";
          } else {
            _status = "Connected";
          }
          
          _isConnected = true;
          _stopAudio(); 
          _pulseController.stop();
          _startTimer();
        } else if (event == CallEvent.callEnded) {
          // ✅ If someone leaves a group call, don't end it for everyone
          if (widget.isGroupCall) {
            _activeGroupUsers--;
            if (_activeGroupUsers > 0) {
              _status = "Connected ($_activeGroupUsers joined)";
            } else {
              _status = "Waiting for others...";
            }
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
           // If I'm ringing and the person who started the group call cancels it, stop ringing
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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F3621), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _buildPulsingAvatar(),
              const SizedBox(height: 30),
              
              // Add Group Call Label
              if (widget.isGroupCall)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8.0),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: const Text("GROUP CALL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),

              Text(
                widget.remoteName,
                style: GoogleFonts.lato(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _isConnected ? _formattedDuration : _status,
                style: GoogleFonts.lato(color: Colors.white70, fontSize: _isConnected ? 20 : 16),
              ),
              const Spacer(flex: 3),
              
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: widget.isIncoming && !_hasAccepted 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionCircle(Icons.call_end, Colors.redAccent, () {
                        if (widget.remoteId != null) {
                          _socketService.endCall(widget.remoteId!, widget.channelName);
                        }
                        _endCallUI("Declined");
                      }),
                      _buildActionCircle(Icons.call, Colors.green, _acceptIncomingCall),
                    ],
                  )
                : Row( 
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
                        // ✅ Loop end_call for group targets if caller drops
                        if (widget.isGroupCall && widget.targetIds != null && !widget.isIncoming) {
                           for(String target in widget.targetIds!) {
                              _socketService.endCall(target, widget.channelName);
                           }
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingAvatar() {
    // ✅ Add this check: Ensure it's not null AND not an empty string
    final bool hasValidAvatar = widget.remoteAvatar != null && widget.remoteAvatar!.isNotEmpty;

    Widget avatar = CircleAvatar(
      radius: 65,
      backgroundColor: Colors.white24,
      backgroundImage: hasValidAvatar ? NetworkImage(widget.remoteAvatar!) : null,
      child: !hasValidAvatar 
        ? Text(widget.remoteName.isNotEmpty ? widget.remoteName[0].toUpperCase() : "?", style: const TextStyle(fontSize: 48, color: Colors.white)) 
        : null,
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
}