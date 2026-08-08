import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth.dart';
import '../services/user_service.dart';

import '../services/token_service.dart';
import 'welcome_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/game_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glass_container.dart';
import '../widgets/language_selector_button.dart';
// import 'package:email_otp/email_otp/email_otp.dart'; // Removed for Firebase flow

class LoginRegisterScreen extends StatefulWidget {
  final VoidCallback onStart;
  final bool isForced;
  const LoginRegisterScreen(
      {super.key, required this.onStart, this.isForced = false});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true;
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _isCheckingUsername = false;

  // Form fields
  String email = '';
  String password = '';
  String confirmPassword = '';
  String firstName = '';
  String lastName = '';
  String username = '';
  String errorMessage = '';

  final Auth _auth = Auth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
  final TextEditingController _usernameController = TextEditingController();

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  @override
  void initState() {
    super.initState();
    _orbController =
        AnimationController(duration: const Duration(seconds: 10), vsync: this)
          ..repeat(reverse: true);
    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _orbController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _orbController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // --- UI Components ---

  Widget _buildBackgroundOrbs() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: -50 + (30 * _orbAnimation.value),
                left: -50 + (20 * _orbAnimation.value),
                child: _buildOrb(
                    200, const Color(0xFF667eea).withValues(alpha: 0.15)),
              ),
              Positioned(
                bottom: 100 - (40 * _orbAnimation.value),
                right: -80 + (30 * _orbAnimation.value),
                child: _buildOrb(
                    250, const Color(0xFF764ba2).withValues(alpha: 0.1)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    TextEditingController? controller,
    Function(String)? onChanged,
    required Function(String?) onSaved,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassContainer(
        borderRadius: 16,
        opacity: 0.1,
        useBlur: false, // Performance optimization
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(color: Colors.white70),
            prefixIcon: Icon(icon, color: Colors.white70),
            suffixIcon: suffixIcon,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.poppins(color: Colors.white),
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          onSaved: onSaved,
          validator: validator,
        ),
      ),
    );
  }

  // --- Logic & Actions ---

  // _signInAsGuest Removed

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => isLoading = true);
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check for anonymous user to link
      final currentUser = FirebaseAuth.instance.currentUser;
      UserCredential userCredential;

      if (currentUser != null && currentUser.isAnonymous) {
        try {
          userCredential = await currentUser.linkWithCredential(credential);
          // Set isGuest to false manually in Firestore
          await _firestore.collection('users').doc(currentUser.uid).update({
            'email': userCredential.user?.email ?? '',
            'isGuest': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Google account already exists, must sign in normally (abandon guest data or todo: merge)
            // For now, just sign in normally
            userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user;

      if (user != null) {
        // Firestore Check/Create (Only if not linked/existing)
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'firstName': user.displayName?.split(' ').first ?? '',
            'lastName': user.displayName?.split(' ').skip(1).join(' ') ?? '',
            'username': user.displayName ?? '',
            'username_lower': (user.displayName ?? '').toLowerCase(),
            'email': user.email ?? '',
            'avatarIndex': '0',
            'createdAt': FieldValue.serverTimestamp(),
            'totalPoints': 0,
            'totalQuizzes': 0,
            'correctAnswers': 0,
            'tokens': 30, // Default start token
            'isEmailVerified': true, // Google ile girenler doğrulanmış sayılır
            'isGuest': false,
          });
        }

        await _syncTokens(user.uid);

        if (mounted) {
          _showSuccessSnackBar('auth.google_success'.tr());
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => WelcomeScreen(onStart: widget.onStart)),
          );
        }
      }
    } catch (e) {
      setState(() => errorMessage = _getReadableErrorMessage(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    if (username.isEmpty || username.length < 3) return false;
    try {
      final normalizedUsername = username.toLowerCase().trim();
      final querySnapshot = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) return false;

      // Legacy check (if username_lower doesn't exist)
      final legacySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();

      return legacySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  void _onUsernameChanged(String value) async {
    if (value.length >= 3) {
      setState(() => _isCheckingUsername = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (_usernameController.text == value) {
        final isAvailable = await _checkUsernameAvailability(value);
        if (mounted && isAvailable) {
          setState(() => _isCheckingUsername = false);
          _formKey.currentState?.validate();
        }
      } else {
        if (mounted) setState(() => _isCheckingUsername = false);
      }
    }
  }

  // --- Form Submission ---

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    _formKey.currentState!.save();

    if (isLogin) {
      try {
        final result =
            await _auth.signInWithEmail(email: email, password: password);

        if (result != null) {
          final user = FirebaseAuth.instance.currentUser;

          // E-posta doğrulama kontrolü kaldırıldı (Kullanıcının isteği üzerine)

          // Token Sync
          if (user != null) {
            await _syncTokens(user.uid);
          }

          if (mounted) {
            setState(() => isLoading = false);
            _showSuccessSnackBar('auth.welcome_back'.tr());
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WelcomeScreen(onStart: widget.onStart),
              ),
            );
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'auth.login_failed'.tr();
          });
        }
      } catch (e) {
        setState(() {
          isLoading = false;
          errorMessage = _getReadableErrorMessage(e);
        });
      }
    } else {
      // Register
      // 1. Password Validation
      if (password.length < 6) {
        setState(() {
          isLoading = false;
          errorMessage = 'auth.password_too_short'.tr();
        });
        return;
      }

      if (password != confirmPassword) {
        setState(() {
          isLoading = false;
          errorMessage = 'auth.password_mismatch'.tr();
        });
        return;
      }

      // 2. Username Validation
      if (username.trim().length < 3) {
        setState(() {
          isLoading = false;
          errorMessage = 'auth.username_too_short'.tr();
        });
        return;
      }

      final isUsernameAvailable = await _checkUsernameAvailability(username);
      if (!isUsernameAvailable) {
        setState(() {
          isLoading = false;
          errorMessage = 'auth.username_taken'.tr();
        });
        return;
      }

      try {
        setState(() => isLoading = true);

        UserCredential? result;
        final currentUser = FirebaseAuth.instance.currentUser;

        // Check if we effectively need to upgrade a guest account
        if (currentUser != null && currentUser.isAnonymous) {
          result = await _auth.linkGuestWithEmail(
            email: email,
            password: password,
            username: username.trim(),
            firstName: firstName.trim(),
            lastName: lastName.trim(),
          );

          if (result != null) {
            // Set isGuest to false manually as well just to be sure
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .update({'isGuest': false});
          }
        } else {
          // Normal registration
          result = await _auth.registerWithEmail(
            email: email,
            password: password,
            username: username.trim(),
            firstName: firstName.trim(),
            lastName: lastName.trim(),
          );
        }

        if (result != null && result.user != null) {
          final user = result.user!;
          await _syncTokens(user.uid);

          if (mounted) {
            setState(() => isLoading = false);
            _showSuccessSnackBar('auth.register_success'.tr());
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WelcomeScreen(onStart: widget.onStart),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("DEBUG: Register Hatasi: $e");
        setState(() {
          isLoading = false;
          errorMessage = _getReadableErrorMessage(e);
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    String resetEmail = '';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_reset, color: Colors.white, size: 40),
              const SizedBox(height: 16),
              Text('auth.reset_password'.tr(),
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('auth.reset_password_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white70)),
              const SizedBox(height: 20),
              TextField(
                onChanged: (val) => resetEmail = val,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  hintText: 'auth.email_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('common.cancel'.tr(),
                          style: const TextStyle(color: Colors.white60))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent),
                      onPressed: () async {
                        if (resetEmail.contains('@')) {
                          try {
                            // Firebase Password Reset
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                                email: resetEmail.trim());

                            if (context.mounted) Navigator.pop(context);
                            if (mounted) {
                              _showSuccessSnackBar(
                                  'auth.email_verification_sent'.tr());
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('${'common.error'.tr()}: $e')));
                            }
                          }
                        }
                      },
                      child: Text('auth.send'.tr()))
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  String _getReadableErrorMessage(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('email-already-in-use')) {
      return 'auth.error_email_in_use'.tr();
    }
    if (errorStr.contains('invalid-email')) {
      return 'auth.error_invalid_email'.tr();
    }
    if (errorStr.contains('weak-password')) {
      return 'auth.error_weak_password'.tr();
    }
    if (errorStr.contains('user-not-found')) {
      return 'auth.error_user_not_found'.tr();
    }
    if (errorStr.contains('wrong-password')) {
      return 'auth.error_wrong_password'.tr();
    }
    return 'auth.error_general'.tr();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text(message)
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _syncTokens(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final tokens = userDoc.data()?['tokens'] as int? ?? 30;
        await TokenService.updateTokenAmount(tokens);
      } else {
        await TokenService.updateTokenAmount(30);
      }
    } catch (e) {
      debugPrint('Token sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Midnight Blue Base
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0F172A)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          _buildBackgroundOrbs(),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    Colors.indigoAccent.withValues(alpha: 0.2),
                                blurRadius: 30,
                                spreadRadius: 5)
                          ]),
                      child: const Icon(Icons.person_outline_rounded,
                          size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 24),

                    // Helper method for animating text logic could go here, keeping it simple for now
                    Text(
                      isLogin
                          ? 'auth.welcome_title'.tr()
                          : 'auth.create_account'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin
                          ? 'auth.login_subtitle'.tr()
                          : 'auth.register_subtitle'.tr(),
                      style: GoogleFonts.poppins(color: Colors.white60),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : _signInWithGoogle,
                            // icon: const Icon(Icons.g_mobiledata, size: 28),
                            icon: const FaIcon(FontAwesomeIcons.google,
                                size: 20, color: Colors.white),
                            label: Text('Google',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setState(() => isLoading = true);
                                    try {
                                      final success =
                                          await GameService().signIn();
                                      if (mounted && success) {
                                        // 2. Firebase Auth ile Link/Giriş Yap (Direkt)
                                        final playGamesCredential =
                                            await Auth().signInWithPlayGames();

                                        if (playGamesCredential == null) {
                                          if (mounted) {
                                            setState(() {
                                              isLoading = false;
                                              errorMessage =
                                                  'Play Games ile Firebase\'e bağlanılamadı. Lütfen ayarlarınızı kontrol edin.';
                                            });
                                          }
                                          return;
                                        }

                                        _showSuccessSnackBar(
                                            'auth.google_success'.tr());

                                        // Link/Update Profile with Play Games Info
                                        final pId =
                                            await GameService().getPlayerID();
                                        final pName =
                                            await GameService().getPlayerName();
                                        await UserService.linkPlayGamesProfile(
                                            pId, pName);

                                        if (context.mounted) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  WelcomeScreen(
                                                      onStart: widget.onStart),
                                            ),
                                          );
                                        }
                                      } else if (mounted) {
                                        setState(() {
                                          isLoading = false;
                                          // Optional: show error if needed, or just stay on page
                                          errorMessage =
                                              'auth.error_general'.tr();
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() {
                                          isLoading = false;
                                          errorMessage =
                                              'auth.error_general'.tr();
                                        });
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.games,
                                size: 20, color: Colors.greenAccent),
                            label: Text('auth.play_games'.tr(),
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('auth.or'.tr(),
                              style: TextStyle(color: Colors.white38))),
                      Expanded(child: Divider(color: Colors.white24))
                    ]),
                    const SizedBox(height: 24),

                    // Form Card
                    GlassContainer(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(24),
                      opacity: 0.08,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (!isLogin) ...[
                              Row(children: [
                                Expanded(
                                    child: _buildTextField(
                                        label: 'auth.first_name_label'.tr(),
                                        icon: Icons.person,
                                        onSaved: (v) => firstName = v!,
                                        validator: (v) => v!.length < 2
                                            ? 'auth.short_input'.tr()
                                            : null)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _buildTextField(
                                        label: 'auth.last_name_label'.tr(),
                                        icon: Icons.person,
                                        onSaved: (v) => lastName = v!,
                                        validator: (v) => v!.length < 2
                                            ? 'auth.short_input'.tr()
                                            : null)),
                              ]),
                              _buildTextField(
                                  label: 'auth.username_label'.tr(),
                                  icon: Icons.alternate_email,
                                  controller: _usernameController,
                                  onChanged: _onUsernameChanged,
                                  onSaved: (v) => username = v!,
                                  suffixIcon: _isCheckingUsername
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : null,
                                  validator: (v) => v!.length < 3
                                      ? 'auth.password_min_length'.tr()
                                      : null),
                            ],
                            _buildTextField(
                                label: 'auth.email_label'.tr(),
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                onSaved: (v) => email = v!,
                                validator: (v) => !v!.contains('@')
                                    ? 'auth.email_invalid'.tr()
                                    : null),
                            _buildTextField(
                                label: 'auth.password_label'.tr(),
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                onSaved: (v) => password = v!,
                                validator: (v) => v!.length < 6
                                    ? 'auth.password_min_length'.tr()
                                    : null,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white60),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                )),
                            if (!isLogin)
                              _buildTextField(
                                  label: 'auth.confirm_password_label'.tr(),
                                  icon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  onSaved: (v) => confirmPassword = v!,
                                  validator: (v) => v!.length < 6
                                      ? 'auth.password_min_length'.tr()
                                      : null,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.white60),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  )),
                            if (isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: Text('auth.forgot_password'.tr(),
                                      style: GoogleFonts.poppins(
                                          color: Colors.indigoAccent,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            const SizedBox(height: 20),
                            if (errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                    color:
                                        Colors.redAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.redAccent
                                            .withValues(alpha: 0.3))),
                                child: Row(children: [
                                  const Icon(Icons.error,
                                      color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(errorMessage,
                                          style: GoogleFonts.poppins(
                                              color: Colors.redAccent,
                                              fontSize: 13)))
                                ]),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text(
                                        isLogin
                                            ? 'auth.login_button'.tr()
                                            : 'auth.register_button'.tr(),
                                        style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Toggle Login/Register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            isLogin
                                ? 'auth.dont_have_account'.tr()
                                : 'auth.already_have_account'.tr(),
                            style: GoogleFonts.poppins(color: Colors.white60)),
                        TextButton(
                          onPressed: () => setState(() {
                            isLogin = !isLogin;
                            errorMessage = '';
                          }),
                          child: Text(
                              isLogin
                                  ? 'auth.register_title'.tr()
                                  : 'auth.login_title'.tr(),
                              style: GoogleFonts.poppins(
                                  color: Colors.indigoAccent,
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),

                    if (!widget.isForced)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('auth.go_back'.tr(),
                              style:
                                  GoogleFonts.poppins(color: Colors.white38)),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: const LanguageSelectorButton(),
          ),
        ],
      ),
    );
  }
}
