import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../widgets/glass_container.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/my_native_ad.dart';

class LoadingScreen extends StatefulWidget {
  final bool isDataReady;
  final VoidCallback? onStart;
  final VoidCallback? onTimeout;
  final int minWaitSeconds;
  final int timeoutSeconds;

  const LoadingScreen({
    super.key,
    this.isDataReady = false,
    this.onStart,
    this.onTimeout,
    this.minWaitSeconds = 5,
    this.timeoutSeconds = 14,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shimmerController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  Timer? _minWaitTimer;
  Timer? _timeoutTimer;
  bool _minTimeElapsed = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

    _orbController =
        AnimationController(duration: const Duration(seconds: 10), vsync: this)
          ..repeat(reverse: true);
    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _orbController, curve: Curves.easeInOut));

    _pulseController =
        AnimationController(duration: const Duration(seconds: 4), vsync: this)
          ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _shimmerController =
        AnimationController(duration: const Duration(seconds: 3), vsync: this)
          ..repeat();

    _progressController =
        AnimationController(duration: Duration(seconds: widget.minWaitSeconds), vsync: this);

    _progressController.forward();

    // 5 saniyede %99'a kadar akıcı animasyon
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.99).animate(
        CurvedAnimation(parent: _progressController, curve: Curves.easeInOutCubic));

    // Minimum 5 saniye bekleme süresi (reklam ve hazır olma senkronu)
    _minWaitTimer = Timer(Duration(seconds: widget.minWaitSeconds), () {
      if (!mounted) return;
      _minTimeElapsed = true;
      _checkAndTriggerStart();
    });

    // 14 saniye zaman aşımı (kullanıcının ekranda asılı kalmasını önler)
    _timeoutTimer = Timer(Duration(seconds: widget.timeoutSeconds), () {
      if (!mounted || _hasStarted) return;
      if (!widget.isDataReady) {
        widget.onTimeout?.call();
      }
    });
  }

  void _checkAndTriggerStart() {
    if (!mounted || _hasStarted) return;
    if (_minTimeElapsed && widget.isDataReady) {
      _hasStarted = true;
      _timeoutTimer?.cancel();
      widget.onStart?.call();
    }
  }

  @override
  void didUpdateWidget(LoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDataReady && !oldWidget.isDataReady) {
      _checkAndTriggerStart();
    }
  }

  @override
  void dispose() {
    _minWaitTimer?.cancel();
    _timeoutTimer?.cancel();
    _orbController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Widget _buildBackgroundOrbs() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: -50 + (100 * _orbAnimation.value),
                left: -100 + (50 * _orbAnimation.value),
                child: _buildOrb(300, const Color(0xFF4F46E5)), // Indigo glow
              ),
              Positioned(
                bottom: 50 - (100 * _orbAnimation.value),
                right: -100 + (50 * _orbAnimation.value),
                child: _buildOrb(350, const Color(0xFFEC4899)), // Pink glow
              ),
              Positioned(
                top: 250 + (100 * (1 - _orbAnimation.value)),
                right: -50,
                child: _buildOrb(250, const Color(0xFF8B5CF6)), // Purple glow
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
        color: color.withValues(alpha: 0.4),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 150, spreadRadius: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF070B19),
                  Color(0xFF131B2F),
                  Color(0xFF070B19)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Floating Orbs
          _buildBackgroundOrbs(),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),

                          // Logo with continuously pulsing glow and rotating scanning rings
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_pulseAnimation, _shimmerController]),
                              builder: (context, child) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Inner pulse glow
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withValues(alpha: _pulseAnimation.value),
                                          blurRadius: 60,
                                          spreadRadius: 10,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFFA855F7).withValues(alpha: _pulseAnimation.value * 0.7),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Rotating dashed ring
                                  Transform.rotate(
                                    angle: _shimmerController.value * 2 * pi,
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Outer fast rotating ring
                                  Transform.rotate(
                                    angle: -_shimmerController.value * 4 * pi,
                                    child: Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEC4899),
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: Color(0xFFEC4899), blurRadius: 10, spreadRadius: 2)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Logo image
                                  ClipOval(
                                    child: Image.asset(
                                      'lib/assets/emilekbul2.png',
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      cacheWidth: 200,
                                      cacheHeight: 200,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.psychology_rounded, size: 100, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // App Title
                          Text(
                            'app_title'.tr(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Progress Section
                          _buildProgressSection(),
                          const SizedBox(height: 28),

                          // Feature Highlights
                          _buildFeatureHighlights(),
                          const SizedBox(height: 24),

                          // Fun fact / tip card
                          _FunFactCard(),
                          const SizedBox(height: 20),
                          const MyNativeAd(
                            height: 120,
                            factoryId: 'adFactoryExample',
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      opacity: 0.12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated loading text (Friendly version)
          DefaultTextStyle(
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            child: AnimatedTextKit(
              animatedTexts: [
                ColorizeAnimatedText(
                  'loading.ai_assistant_preparing'.tr(),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  colors: [Colors.white, const Color(0xFF6366F1), const Color(0xFFA855F7), Colors.white],
                  speed: const Duration(milliseconds: 150),
                ),
                ColorizeAnimatedText(
                  'loading.selecting_questions'.tr(),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  colors: [Colors.white, const Color(0xFF6366F1), const Color(0xFFA855F7), Colors.white],
                  speed: const Duration(milliseconds: 150),
                ),
                ColorizeAnimatedText(
                  'loading.almost_ready'.tr(),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  colors: [Colors.white, const Color(0xFF6366F1), const Color(0xFFA855F7), Colors.white],
                  speed: const Duration(milliseconds: 150),
                ),
              ],
              repeatForever: true,
            ),
          ),
          const SizedBox(height: 20),

          // Rich Glowing Line instead of simple percentage bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF9333EA), Color(0xFFEC4899)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9333EA).withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.psychology_rounded,
            label: 'loading.ai_powered'.tr(),
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.category_rounded,
            label: 'loading.categories'.tr(),
            color: const Color(0xFFA855F7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.emoji_events_rounded,
            label: 'loading.compete'.tr(),
            color: const Color(0xFFEC4899),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GlassContainer(
      borderRadius: 20,
      opacity: 0.12,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Rotating fun-fact card - keeps users engaged while waiting
class _FunFactCard extends StatefulWidget {
  @override
  State<_FunFactCard> createState() => _FunFactCardState();
}

class _FunFactCardState extends State<_FunFactCard>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _funFactKeys = [
    'welcome.fun_fact_1',
    'welcome.fun_fact_2',
    'welcome.fun_fact_3',
    'welcome.fun_fact_4',
    'welcome.fun_fact_5',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = Random().nextInt(_funFactKeys.length);
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _fadeCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _funFactKeys.length;
        });
        _fadeCtrl.forward();
        _scheduleNext();
      });
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: GlassContainer(
        borderRadius: 20,
        opacity: 0.15,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lightbulb_rounded,
                  color: Colors.amber.withValues(alpha: 0.8), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'loading.did_you_know'.tr(),
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _funFactKeys[_currentIndex].tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
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
