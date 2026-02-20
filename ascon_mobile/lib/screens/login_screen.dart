import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; 
import 'package:go_router/go_router.dart'; 

import '../services/auth_service.dart';
import '../services/notification_service.dart'; 
import '../services/socket_service.dart'; 
import '../services/biometric_service.dart'; 
import '../config.dart'; 
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'welcome_dialog.dart'; 
import 'edit_profile_screen.dart'; // ✅ Required for profile completion

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
  final BiometricService _biometricService = BiometricService(); 

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

  // ✅ ADDED: Dispose method to prevent memory leaks
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

    // ✅ CRITICAL: ENFORCE PROFILE COMPLETION
    // If yearOfAttendance is missing (null, 0, or "null"), stop here and redirect.
    var year = user['yearOfAttendance'];
    if (year == null || year == 0 || year == "null" || year.toString().trim().isEmpty) {
      debugPrint("⚠️ Incomplete Profile Detected. Redirecting to Edit Profile.");
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfileScreen(
            userData: user,
            isFirstTime: true, // ✅ Forces "Onboarding Mode" (No back button)
          ),
        ),
      );
      return;
    }

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

    // A modern input decoration template
    InputDecoration modernInputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor, size: 22),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // ✅ Makes elements fill width naturally
              children: [
                Center(
                  child: Container(
                    height: 110, width: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: cardColor,
                      boxShadow: [BoxShadow(color: isDark ? Colors.black38 : Colors.black12, blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.school, size: 60, color: primaryColor))),
                  ),
                ),
                const SizedBox(height: 32), 
                
                Text('Welcome Back', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Sign in to access your alumni network', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 36), 

                // ✅ OPTIMIZED: Email Keyboard & Next Action
                TextFormField(
                  controller: _emailController, 
                  enabled: !isAnyLoading, 
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: modernInputDecoration('Email Address', Icons.email_outlined),
                ),
                const SizedBox(height: 16), 
                
                // ✅ OPTIMIZED: Done Action
                TextFormField(
                  controller: _passwordController, 
                  enabled: !isAnyLoading, 
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => loginUser(), // Hit enter to login
                  decoration: modernInputDecoration('Password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 22), 
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword)
                    ),
                  ),
                ),
                
                Align(
                  alignment: Alignment.centerRight, 
                  child: TextButton(
                    onPressed: isAnyLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), 
                    child: Text("Forgot Password?", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13))
                  )
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54, // ✅ Taller, more premium button
                        child: ElevatedButton(
                          onPressed: isAnyLoading ? null : loginUser, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor, 
                            foregroundColor: Colors.white, 
                            elevation: 2,
                            shadowColor: primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ), 
                          child: _isEmailLoading 
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                            : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2))
                        )
                      ),
                    ),
                    if (_canCheckBiometrics) ...[
                      const SizedBox(width: 16),
                      Container(
                        height: 54, width: 54,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5)
                        ),
                        child: IconButton(
                          icon: Icon(Icons.fingerprint, color: primaryColor, size: 28),
                          onPressed: isAnyLoading ? null : _handleBiometricLogin,
                        ),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 30),

                // ✅ ADDED: Premium "OR" Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], thickness: 1)),
                  ],
                ),
                const SizedBox(height: 30),

                SizedBox(
                  height: 54, 
                  child: OutlinedButton(
                    onPressed: isAnyLoading ? null : signInWithGoogle, 
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1.5), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                      backgroundColor: cardColor
                    ), 
                    child: _isGoogleLoading 
                      ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5)) 
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            // You can replace this icon with a Google SVG asset later
                            Icon(Icons.g_mobiledata_rounded, color: isDark ? Colors.white : Colors.black87, size: 32), 
                            const SizedBox(width: 8), 
                            Text(
                              "Continue with Google", 
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)
                            )
                          ]
                        )
                  )
                ),
                const SizedBox(height: 40),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Text("New here? ", style: TextStyle(fontSize: 14, color: subTextColor)), 
                    GestureDetector(
                      onTap: () { 
                        if (!isAnyLoading) Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())); 
                      }, 
                      child: Text("Create Account", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 14))
                    )
                  ]
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}