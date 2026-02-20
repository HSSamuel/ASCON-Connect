import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/call_service.dart';
import '../services/socket_service.dart';

class CallScreen extends StatefulWidget {
  final String remoteName;
  final String remoteId;
  final String channelName; // The unique room name (e.g. "call_123_456")
  final String? remoteAvatar; 
  final bool isIncoming; 

  const CallScreen({
    super.key, 
    required this.remoteName, 
    required this.remoteId,
    required this.channelName,
    this.remoteAvatar,
    this.isIncoming = false, 
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final CallService _callService = CallService();
  final SocketService _socketService = SocketService();
  
  String _status = "Connecting...";
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  bool _hasAccepted = false;

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
    } else {
      _status = "Ringing...";
      _startOutgoingCall();
    }
  }

  void _startOutgoingCall() async {
    // 1. Join the Agora Channel
    bool success = await _callService.joinCall(channelName: widget.channelName);
    
    if (success) {
      // 2. Tell the other user's phone to ring via Socket
      _socketService.initiateCall(widget.remoteId, widget.channelName, {
        'callerName': "Ascon User", // Replace with actual current user name if available
        'callerAvatar': null
      });
    } else {
      _endCallUI("Call Failed");
    }
  }

  void _acceptIncomingCall() async {
    setState(() {
      _hasAccepted = true;
      _status = "Connecting...";
    });
    
    // 1. Tell caller we answered
    _socketService.answerCall(widget.remoteId, widget.channelName);
    
    // 2. Join the Agora Audio Room
    await _callService.joinCall(channelName: widget.channelName);
  }

  void _listenToEvents() {
    // Listen to Agora Audio Engine Events
    _listener = _callService.callEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event == CallEvent.connected) {
          _status = "Connected";
          _isConnected = true;
          _pulseController.stop();
          _startTimer();
        } else if (event == CallEvent.callEnded) {
          _endCallUI("Call Ended");
        }
      });
    });

    // Listen to Socket Events (if the other person hangs up while ringing)
    _socketListener = _socketService.callEvents.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'ended' && event['data']['channelName'] == widget.channelName) {
        _endCallUI("Call Ended");
      } else if (event['type'] == 'answered' && event['data']['channelName'] == widget.channelName) {
        setState(() => _status = "Connecting Audio...");
      }
    });
  }

  void _endCallUI(String message) {
    setState(() => _status = message);
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
              Text(
                widget.remoteName,
                style: GoogleFonts.lato(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _isConnected ? _formattedDuration : _status,
                style: GoogleFonts.lato(color: Colors.white70, fontSize: _isConnected ? 20 : 16),
              ),
              const Spacer(flex: 3),
              
              // Controls UI
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: widget.isIncoming && !_hasAccepted 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline Button
                      _buildActionCircle(Icons.call_end, Colors.redAccent, () {
                        _socketService.endCall(widget.remoteId, widget.channelName);
                        _endCallUI("Declined");
                      }),
                      // Accept Button
                      _buildActionCircle(Icons.call, Colors.green, _acceptIncomingCall),
                    ],
                  )
                : Row( // Active Call Controls
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
                        _socketService.endCall(widget.remoteId, widget.channelName);
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
    Widget avatar = CircleAvatar(
      radius: 65,
      backgroundColor: Colors.white24,
      backgroundImage: widget.remoteAvatar != null ? NetworkImage(widget.remoteAvatar!) : null,
      child: widget.remoteAvatar == null ? Text(widget.remoteName[0].toUpperCase(), style: const TextStyle(fontSize: 48, color: Colors.white)) : null,
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