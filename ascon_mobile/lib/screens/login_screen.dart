import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; 
import 'package:go_router/go_router.dart'; 

import '../services/auth_service.dart';
import '../services/notification_service.dart'; 
import '../services/socket_service.dart'; 
import '../services/biometric_service.dart'; // ✅ Added import
import '../config.dart'; 
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'welcome_dialog.dart'; 

class LoginScreen extends StatefulWidget {
  final Map<String, dynamic>? pendingNavigation;

  const LoginScreen({super.key, this.pendingNavigation});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService(); // ✅ Instance

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
  );
  
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true; 
  bool _canCheckBiometrics = false;

  @override
void initState() {
  super.initState();
  // ✅ Only check biometrics if NOT running on Web
  if (!kIsWeb) {
    _checkBiometrics();
  }
}

  Future<void> _checkBiometrics() async {
    bool available = await _biometricService.isBiometricAvailable;
    if (mounted) setState(() => _canCheckBiometrics = available);
  }

  // ✅ OPT-IN DIALOG for Biometrics
  void _showBiometricOptInDialog(String email, String password, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enable Biometric Login?"),
        content: const Text("Would you like to use FaceID/Fingerprint for faster access next time?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLoginSuccess(user);
            },
            child: const Text("SKIP"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.enableBiometrics(email, password);
              if (mounted) {
                Navigator.pop(context);
                _handleLoginSuccess(user);
              }
            },
            child: const Text("ENABLE"),
          ),
        ],
      ),
    );
  }

  // ✅ HANDLE BIOMETRIC BUTTON TAP
  Future<void> _handleBiometricLogin() async {
    bool hasConsent = await _authService.isBiometricEnabled();
    if (!hasConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in with password once to enable Biometrics.")),
      );
      return;
    }

    bool authenticated = await _biometricService.authenticate();
    if (authenticated) {
      setState(() => _isEmailLoading = true); 
      final result = await _authService.loginWithStoredCredentials();
      if (mounted) setState(() => _isEmailLoading = false);

      if (result['success']) {
        _handleLoginSuccess(result['data']['user']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Biometric login failed: ${result['message']}")),
        );
      }
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> user) async {
    _syncNotificationToken();

    if (user['id'] != null || user['_id'] != null) {
      final String userId = user['id'] ?? user['_id'];
      SocketService().connectUser(userId);
    }

    String safeName = user['fullName'] ?? "Alumni"; 

    // Handle Pending Navigation
    if (widget.pendingNavigation != null) {
      debugPrint("🚀 Handling Pending Navigation after Login...");
      context.go('/home');
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService().handleNavigation(widget.pendingNavigation!);
      });
      return; 
    }

    bool hasSeenWelcome = user['hasSeenWelcome'] ?? false;

    if (hasSeenWelcome) {
      _navigateToHome(safeName);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeDialog(
          userName: safeName,
          onGetStarted: () async {
            await _markWelcomeAsSeen();
            if (mounted) _navigateToHome(safeName); 
          }, 
        ),
      );
    }
  }

  Future<void> _syncNotificationToken() async {
    if (kIsWeb) return; 
    try {
      await NotificationService().syncToken();
    } catch (e) {
      debugPrint("⚠️ Failed to sync token on login: $e");
    }
  }

  Future<void> _markWelcomeAsSeen() async {
    try {
      await _authService.markWelcomeSeen(); 
    } catch (e) {
      debugPrint("❌ Failed to mark welcome as seen: $e");
    }
  }

  void _navigateToHome(String userName) {
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all fields"), backgroundColor: Colors.orange));
      return;
    }
    FocusScope.of(context).unfocus();
    
    setState(() => _isEmailLoading = true);
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final result = await _authService.login(email, password);
      
      if (!mounted) return;

      if (result['success']) {
        setState(() => _isEmailLoading = false);
        
        // ✅ Check if we should prompt for Biometrics
        bool alreadyEnabled = await _authService.isBiometricEnabled();
        bool hardwareAvailable = await _biometricService.isBiometricAvailable;

        if (!alreadyEnabled && hardwareAvailable && mounted) {
          _showBiometricOptInDialog(email, password, result['data']['user']);
        } else {
          _handleLoginSuccess(result['data']['user']);
        }
      } else {
        setState(() => _isEmailLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) setState(() => _isEmailLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      setState(() => _isGoogleLoading = true);
      
      GoogleSignInAccount? googleUser;
      if (kIsWeb) {
        try { googleUser = await _googleSignIn.signInSilently(); } catch (e) {}
      }
      if (googleUser == null) {
        try { googleUser = await _googleSignIn.signIn(); } catch (error) {
          setState(() => _isGoogleLoading = false);
          return; 
        }
      }
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? tokenToSend = googleAuth.idToken ?? googleAuth.accessToken;

      if (tokenToSend == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      final result = await _authService.googleLogin(tokenToSend);
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (result['success']) {
        if (result['statusCode'] == 200) {
          _handleLoginSuccess(result['data']['user']);
        } else if (result['statusCode'] == 404) {
          final googleData = result['data']['googleData'];
          Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(
            prefilledName: googleData['fullName'], 
            prefilledEmail: googleData['email'],
            googleToken: googleAuth.idToken,
          )));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Google Login Failed"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred during Google Login."), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardColor;
    final bool isAnyLoading = _isEmailLoading || _isGoogleLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    height: 100, width: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: isDark ? Colors.black38 : Colors.black12, blurRadius: 15, offset: const Offset(0, 8))]),
                    child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.school, size: 80, color: primaryColor))),
                  ),
                ),
                const SizedBox(height: 16), 
                Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 4),
                Text('Sign in to access your alumni network', style: TextStyle(fontSize: 13, color: subTextColor)),
                const SizedBox(height: 24), 

                TextFormField(controller: _emailController, enabled: !isAnyLoading, decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20))),
                const SizedBox(height: 12), 
                TextFormField(
                  controller: _passwordController, enabled: !isAnyLoading, obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
                    suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                  ),
                ),
                
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: isAnyLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: Text("Forgot Password?", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)))),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45, 
                        child: ElevatedButton(
                          onPressed: isAnyLoading ? null : loginUser, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor, 
                            foregroundColor: Colors.white, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ), 
                          child: _isEmailLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Text('LOGIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))
                        )
                      ),
                    ),
                    if (_canCheckBiometrics) ...[
                      const SizedBox(width: 12),
                      Container(
                        height: 45, width: 45,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryColor.withOpacity(0.5))
                        ),
                        child: IconButton(
                          icon: Icon(Icons.fingerprint, color: primaryColor),
                          onPressed: isAnyLoading ? null : _handleBiometricLogin,
                        ),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, height: 45, child: OutlinedButton(onPressed: isAnyLoading ? null : signInWithGoogle, style: OutlinedButton.styleFrom(side: BorderSide(color: primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), backgroundColor: cardColor), child: _isGoogleLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login, color: primaryColor, size: 20), const SizedBox(width: 8), Text("Continue with Google", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14))]))),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("New here? ", style: TextStyle(fontSize: 13, color: subTextColor)), GestureDetector(onTap: () { if (!isAnyLoading) Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())); }, child: Text("Create Account", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)))]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}