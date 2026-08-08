import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/user_service.dart';
import '../services/fullscreen_service.dart';
import '../main.dart'; // To navigate to QuizFlow

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Set system UI to immersive for splash screen specifically
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.5, end: 1.2)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.2, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50),
    ]).animate(_controller);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _startInitialization();
  }

  Future<void> _startInitialization() async {
    // Both animation and backend setup happen concurrently
    await Future.wait([
      _controller.forward(),
      _setupApp(),
    ]);

    // Give a tiny buffer for smoothness
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const QuizFlow(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _setupApp() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Auto Guest Login in the background during splash!
        debugPrint("Splash: Starting background guest login...");
        final userCredential = await UserService.signInAsGuest().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Guest Login Timeout"),
        );
        if (userCredential != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_seen_onboarding_v2', true);
          await prefs.setInt('user_tokens', 50); // initial tokens
        }
      }
    } catch (e) {
      debugPrint("Splash init error: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('lib/assets/emilekbul2.png'), context);
  }

  @override
  void dispose() {
    FullScreenService.applyCurrentMode();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B19), // Darker, richer background
      body: Stack(
        children: [
          // Ambient Background Glows
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = _controller.value;
              return Stack(
                children: [
                  Positioned(
                    top: -100 - (50 * val),
                    left: -100 + (100 * val),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15 + (0.1 * val)),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 150, spreadRadius: 50),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150 + (100 * val),
                    right: -100 - (50 * val),
                    child: Container(
                      width: 450,
                      height: 450,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEC4899).withValues(alpha: 0.1 + (0.1 * val)),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.25), blurRadius: 150, spreadRadius: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Main Content
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'lib/assets/emilekbul2.png',
                        width: 140,
                        height: 140,
                        cacheWidth: 420,
                        cacheHeight: 420,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'app_title'.tr(),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // A subtle loading indicator
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
