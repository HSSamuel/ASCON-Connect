import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart'; 
import '../services/call_service.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';

class CallScreen extends StatefulWidget {
  final String remoteName;
  final String remoteId;
  final String? remoteAvatar;
  final bool isCaller; 
  final Map<String, dynamic>? offer; 

  const CallScreen({
    super.key,
    required this.remoteName,
    required this.remoteId,
    this.remoteAvatar,
    required this.isCaller,
    this.offer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final CallService _callService = CallService();
  final SocketService _socketService = SocketService();
  
  late AnimationController _pulseController;
  late AudioPlayer _audioPlayer;
  StreamSubscription? _callStateSubscription;

  String _status = "Initializing...";
  bool _isMuted = false;
  bool _isSpeakerOn = false; 
  bool _hasAnswered = false;
  bool _permissionDenied = false;

  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _setupCallListeners();
    Future.delayed(const Duration(milliseconds: 500), _initCallSequence);
  }

  void _startCallTimer() {
    if (_callTimer != null) return;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _setupCallListeners() {
    _callStateSubscription = _callService.callStateStream.listen((state) {
      if (!mounted) return;

      switch (state) {
        case CallState.connected:
          _stopRinging();
          _triggerVibration(pattern: [0, 100, 50, 100]); 
          
          _startCallTimer();
          setState(() {
            _status = "Connected";
            _hasAnswered = true;
          });
          break;
          
        case CallState.idle:
          _stopRinging();
          _triggerVibration(pattern: [0, 500]);
          
          _callTimer?.cancel();
          if (mounted && context.canPop()) context.pop();
          break;
          
        case CallState.incoming:
          setState(() => _status = "Incoming Call...");
          break;
        case CallState.calling:
          setState(() => _status = "Calling...");
          break;
      }
    });

    _socketService.callEvents.listen((event) {
       if (event['type'] == 'answer_made' && widget.isCaller) {
         _callService.handleAnswer(event['data']['answer']);
       } else if (event['type'] == 'ice_candidate') {
         _callService.handleIceCandidate(event['data']['candidate']);
       }
    });
  }

  Future<void> _initCallSequence() async {
    setState(() => _permissionDenied = false);
    
    if (SocketService().socket == null || !SocketService().socket!.connected) {
       setState(() => _status = "Connecting to Server...");
       await SocketService().initSocket();
    }

    try {
      if (widget.isCaller) {
        setState(() => _status = "Calling...");
        _playRingtone(isDialing: true);
        await _callService.startCall(widget.remoteId);
      } else {
        setState(() => _status = "Incoming Call...");
        _playRingtone(isDialing: false);
      }
    } catch (e) {
      debugPrint("Call Init Error: $e");
      _stopRinging();
      
      // ✅ SAFETY CHECK: Do not call setState if widget is disposed
      if (!mounted) return;

      if (e.toString().contains("NotAllowedError") || e.toString().contains("Permission dismissed")) {
        setState(() {
          _status = "Microphone Permission Denied";
          _permissionDenied = true;
        });
      } else {
        setState(() => _status = "Connection Failed");
      }
    }
  }

  Future<void> _playRingtone({required bool isDialing}) async {
    try {
      String sound = isDialing ? 'sounds/dialing.mp3' : 'sounds/ringtone.mp3';
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(sound));

      if (!kIsWeb && !isDialing && await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 1);
      }
    } catch (e) {
      debugPrint("⚠️ Audio Play Warning (Ignored): $e");
    }
  }

  Future<void> _triggerVibration({required List<int> pattern}) async {
    if (kIsWeb) return;
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: pattern); 
      }
    } catch (_) {}
  }

  Future<void> _stopRinging() async {
    try {
      await _audioPlayer.stop();
      if (!kIsWeb) Vibration.cancel();
    } catch (_) {}
  }

  void _onAnswer() async {
    _stopRinging();
    if (widget.offer != null) {
      try {
        setState(() {
          _status = "Connecting...";
          _hasAnswered = true;
        });
        await _callService.answerCall(widget.offer!, widget.remoteId);
      } catch (e) {
        if (!mounted) return;
        setState(() {
           _status = "Microphone Blocked";
           _permissionDenied = true;
           _hasAnswered = false; 
        });
      }
    }
  }

  void _onDecline() {
    _stopRinging();
    _callService.endCall();
    if (mounted && context.canPop()) context.pop();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _stopRinging();
    _audioPlayer.dispose();
    _callStateSubscription?.cancel();
    _pulseController.dispose();
    _callService.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool showIncomingControls = !widget.isCaller && !_hasAnswered;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.remoteAvatar != null && widget.remoteAvatar!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.remoteAvatar!,
              fit: BoxFit.cover,
            )
          else
            Container(color: const Color(0xFF0F3621)), 

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withOpacity(0.6), 
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 1),
                _buildAvatar(widget.remoteAvatar, 150, _status.contains("Incoming") || _status.contains("Calling")),
                const SizedBox(height: 25),
                Text(
                  widget.remoteName,
                  style: GoogleFonts.lato(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _permissionDenied ? Colors.red.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (_hasAnswered && _callDuration.inSeconds > 0) 
                        ? _formatDuration(_callDuration) 
                        : _status,
                    style: GoogleFonts.lato(
                      color: _permissionDenied ? Colors.redAccent : Colors.white70,
                      fontSize: (_hasAnswered && _callDuration.inSeconds > 0) ? 20 : 15,
                      fontWeight: (_hasAnswered && _callDuration.inSeconds > 0) ? FontWeight.bold : FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (_permissionDenied)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.mic, color: Colors.white),
                      label: const Text("Allow Microphone Access"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _initCallSequence,
                    ),
                  ),
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.only(bottom: 50, top: 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                  child: showIncomingControls 
                    ? _buildIncomingControls() 
                    : _buildActiveCallControls(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildAvatar(String? url, double size, bool pulse) {
    Widget image = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 4),
        image: (url != null && url.isNotEmpty) 
          ? DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover)
          : null,
      ),
      child: (url == null || url.isEmpty)
          ? Icon(Icons.person, size: size * 0.4, color: Colors.white54)
          : null,
    );

    if (pulse) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
            child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1))),
          ),
          image,
        ],
      );
    }
    return image;
  }

  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircleButton(color: Colors.redAccent, icon: Icons.call_end, label: "Decline", onTap: _onDecline),
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
          child: _buildCircleButton(color: const Color(0xFF1B5E3A), icon: Icons.call, label: "Answer", onTap: _onAnswer, size: 80),
        ),
      ],
    );
  }

  Widget _buildActiveCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildGlassOption(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: "Mute",
          isActive: _isMuted,
          onTap: () {
            setState(() => _isMuted = !_isMuted);
            _callService.toggleMute(_isMuted);
          },
        ),
        FloatingActionButton.large(
          onPressed: () {
            _stopRinging();
            _callService.endCall();
            if (mounted && context.canPop()) context.pop();
          },
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
        ),
        _buildGlassOption(
          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          label: "Speaker",
          isActive: _isSpeakerOn,
          onTap: () {
            setState(() => _isSpeakerOn = !_isSpeakerOn);
            _callService.toggleSpeaker(_isSpeakerOn);
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton({required Color color, required IconData icon, required String label, required VoidCallback onTap, double size = 65}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15)]),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _buildGlassOption({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}