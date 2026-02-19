import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String remoteName;
  final String remoteId;

  // ✅ Fixed Constructor
  const CallScreen({
    super.key, 
    required this.remoteName, 
    required this.remoteId
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  String _status = "Initializing...";
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  StreamSubscription<CallEvent>? _listener;

  @override
  void initState() {
    super.initState();
    _startCall();
    _listenToEvents();
  }

  void _startCall() async {
    setState(() => _status = "Calling...");
    await _callService.placeCall(widget.remoteId, widget.remoteName);
  }

  void _listenToEvents() {
    _listener = _callService.callEvents.listen((event) {
      if (!mounted) return;

      setState(() {
        // ✅ FIXED: Using Enum comparison
        switch (event) {
          case CallEvent.connected:
            _status = "Connected";
            break;
          case CallEvent.ringing:
            _status = "Ringing...";
            break;
          case CallEvent.callEnded:
            _status = "Ended";
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

  @override
  void dispose() {
    _listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              child: Text(
                widget.remoteName.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              widget.remoteName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            
            const Spacer(flex: 2),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 32),
                    onPressed: () {
                      setState(() => _isMuted = !_isMuted);
                      _callService.toggleMute(_isMuted);
                    },
                  ),
                  FloatingActionButton.large(
                    backgroundColor: Colors.redAccent,
                    onPressed: () {
                      _callService.hangUp();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                  ),
                  IconButton(
                    icon: Icon(_isSpeakerOn ? Icons.volume_up : Icons.volume_down, color: Colors.white, size: 32),
                    onPressed: () {
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
    );
  }
}