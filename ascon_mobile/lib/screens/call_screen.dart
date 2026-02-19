import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twilio_voice/twilio_voice.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String remoteName;
  final String remoteId;
  final String? remoteAvatar; 
  final bool isIncoming; // ✅ FIX: Added to prevent auto-dialing an incoming answered call

  const CallScreen({
    super.key, 
    required this.remoteName, 
    required this.remoteId,
    this.remoteAvatar,
    this.isIncoming = false, 
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final CallService _callService = CallService();
  String _status = "Connecting...";
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;

  StreamSubscription<CallEvent>? _listener;
  
  // Timer for active call
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  // Animation for ringing pulse
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    // Setup Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat(reverse: true);

    _listenToEvents();

    // ✅ FIX: Discern call direction. Incoming calls are already ringing/connected by Twilio Native CallKit UI.
    if (!widget.isIncoming) {
      _status = "Calling...";
      _startCall();
    } else {
      // It's an incoming call being displayed in-app. Default to UI connected state if already answered.
      _status = "Connected";
      _isConnected = true;
      _pulseController.stop();
      _startTimer();
    }
  }

  void _startCall() async {
    bool success = await _callService.placeCall(widget.remoteId, widget.remoteName);
    
    // If it failed to start, show an error and exit
    if (!success && mounted) {
      setState(() {
        _status = "Call Failed to Start";
      });
      _pulseController.stop(); // Stop the animation
      
      // Close the screen after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
  }

  void _listenToEvents() {
    _listener = _callService.callEvents.listen((event) {
      if (!mounted) return;

      setState(() {
        switch (event) {
          case CallEvent.connected:
            _status = "Connected";
            _isConnected = true;
            _pulseController.stop(); // Stop pulsing when answered
            _startTimer();
            break;
          case CallEvent.ringing:
            _status = "Ringing...";
            break;
          case CallEvent.callEnded:
            _status = "Call Ended";
            _stopTimer();
            Future.delayed(const Duration(seconds: 1), () {
               if (mounted && Navigator.canPop(context)) Navigator.pop(context);
            });
            break;
          default:
            break;
        }
      });
    });
  }

  void _startTimer() {
    // Prevent multiple timers if already started
    if (_callTimer != null && _callTimer!.isActive) return;

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
  }

  String get _formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(_callDuration.inMinutes.remainder(60));
    String seconds = twoDigits(_callDuration.inSeconds.remainder(60));
    if (_callDuration.inHours > 0) {
      return "${twoDigits(_callDuration.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _listener?.cancel();
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
            colors: [
              Color(0xFF0F3621), // ASCON Dark Green
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // 1. Avatar with Ripple Animation
              _buildPulsingAvatar(),
              
              const SizedBox(height: 30),
              
              // 2. Caller Name
              Text(
                widget.remoteName,
                style: GoogleFonts.lato(
                  color: Colors.white, 
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // 3. Status or Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isConnected ? _formattedDuration : _status,
                  style: GoogleFonts.lato(
                    color: Colors.white70, 
                    fontSize: _isConnected ? 20 : 16,
                    fontWeight: _isConnected ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              const Spacer(flex: 3),
              
              // 4. Modern Glassmorphic Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: "Mute",
                      isActive: _isMuted,
                      activeColor: Colors.black,
                      onTap: () {
                        setState(() => _isMuted = !_isMuted);
                        _callService.toggleMute(_isMuted);
                      },
                    ),
                    
                    // Hangup Button
                    GestureDetector(
                      onTap: () {
                        _callService.hangUp();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.redAccent, blurRadius: 15, spreadRadius: 2)
                          ]
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
                      ),
                    ),

                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      label: "Speaker",
                      isActive: _isSpeakerOn,
                      activeColor: Colors.black,
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

  // --- UI HELPER METHODS ---

  Widget _buildPulsingAvatar() {
    Widget avatar = CircleAvatar(
      radius: 65,
      backgroundColor: Colors.white24,
      backgroundImage: widget.remoteAvatar != null && widget.remoteAvatar!.isNotEmpty
          ? NetworkImage(widget.remoteAvatar!) // Works if you pass URLs later
          : null,
      child: (widget.remoteAvatar == null || widget.remoteAvatar!.isEmpty)
          ? Text(
              widget.remoteName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
            )
          : null,
    );

    // If connected, no pulse.
    if (_isConnected) return avatar;

    // Pulse animation while dialing/ringing
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.3).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
          ),
          child: Container(
            width: 130, 
            height: 130, 
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: Colors.white.withOpacity(0.1)
            ),
          ),
        ),
        avatar,
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon, 
    required String label, 
    required bool isActive, 
    required Color activeColor,
    required VoidCallback onTap
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Icon(icon, color: isActive ? activeColor : Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60, 
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal
          ),
        )
      ],
    );
  }
}