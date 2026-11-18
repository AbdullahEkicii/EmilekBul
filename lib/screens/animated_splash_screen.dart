import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/analytics_service.dart';
import '../services/fullscreen_service.dart';
import '../services/league_service.dart';
import '../services/remote_flags.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _fxController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _barProgress;

  final Stopwatch _sw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.58, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.24, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.26, 0.70, curve: Curves.easeOut),
      ),
    );

    _barProgress = Tween<double>(begin: 0.06, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.10, 0.98, curve: Curves.easeInOutCubic),
      ),
    );

    _startInitialization();
  }

  Future<void> _startInitialization() async {
    // Arka plan kurulumunu hemen başlat; görsel splash sayacını ilk kare ekrana çizildikten sonra ölç
    final setupFuture =
        _setupApp().timeout(const Duration(seconds: 3), onTimeout: () {});

    final firstFrame = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!firstFrame.isCompleted) firstFrame.complete();
    });
    await firstFrame.future;
    if (!mounted) return;

    await Future.wait([
      _introController.forward(),
      Future.delayed(const Duration(milliseconds: 2200)),
      setupFuture,
    ]);

    AnalyticsService.logFirstSession('splash_done', {
      'ms': _sw.elapsedMilliseconds,
      'user_ready': FirebaseAuth.instance.currentUser != null ? 1 : 0,
    });

    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding =
        prefs.getBool('has_seen_onboarding_v3') ?? false;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            hasSeenOnboarding ? const QuizFlow() : const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 650),
      ),
    );
  }

  Future<void> _setupApp() async {
    // Remote Config: asla bloklamaz, hatalar içeride yakalanır
    unawaited(RemoteFlags.init());
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint("Splash: Starting background guest login...");
        await UserService.signInAsGuest().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception("Guest Login Timeout"),
        );
      } else {
        AnalyticsService.setUserId(currentUser.uid);
        UserService.ensureUsernameLowerIndex(currentUser.uid);
      }

      unawaited(
        LeagueService.getMyLeague().catchError((_) => LeagueService.leagues.first),
      );
      UserService.triggerPeriodicGuestCleanup();
    } catch (e) {
      debugPrint("Splash init error: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('lib/assets/app_icon.png'), context);
  }

  @override
  void dispose() {
    FullScreenService.applyCurrentMode();
    _introController.dispose();
    _fxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF060E1E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Tam ekran Coastal Twilight derinlik gradyanı
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060E1E),
                  Color(0xFF0C1D36),
                  Color(0xFF122B4D),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Hareketli tam ekran aurora ışınları, şok dalgaları, parçacıklar ve yörüngeler
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _fxController]),
              builder: (context, _) {
                return CustomPaint(
                  size: size,
                  painter: _SplashFullScreenFXPainter(
                    fxPhase: _fxController.value,
                    introProgress: _introController.value,
                  ),
                );
              },
            ),
          ),

          // Merkez amblem ve başlık koreografisi
          Align(
            alignment: const Alignment(0, -0.08),
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _fxController]),
              builder: (context, _) {
                final floatY =
                    math.sin(_fxController.value * 2 * math.pi) * 4.5;
                final shimmerPos = (_fxController.value * 1.6) % 1.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, floatY),
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Hero(
                            tag: 'app_logo',
                            child: _SplashEmblem(shimmerProgress: shimmerPos),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'app_title'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Color(0x8838BDF8),
                                    blurRadius: 22,
                                  ),
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accent.withValues(alpha: 0.22),
                                    AppColors.amber.withValues(alpha: 0.16),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.18),
                                    blurRadius: 18,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: Text(
                                'welcome_screen.app_subtitle'.tr(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE2E8F0),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Alt yükleme çubuğu
          Positioned(
            left: 44,
            right: 44,
            bottom: 54,
            child: AnimatedBuilder(
              animation: _introController,
              builder: (context, _) {
                final progress = _barProgress.value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: _textOpacity.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF38BDF8),
                                    Color(0xFFA78BFA),
                                    Color(0xFFFBBF24),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8)
                                        .withValues(alpha: 0.65),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'welcome.loading'.tr(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashEmblem extends StatelessWidget {
  final double shimmerProgress;

  const _SplashEmblem({required this.shimmerProgress});

  @override
  Widget build(BuildContext context) {
    final sweepBegin = -1.6 + (shimmerProgress * 3.2);
    final sweepEnd = sweepBegin + 1.0;

    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            const Color(0xFF38BDF8).withValues(alpha: 0.14),
            const Color(0xFF818CF8).withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.38),
            blurRadius: 42,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
            blurRadius: 30,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(37),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'lib/assets/app_icon.png',
                width: 112,
                height: 112,
                cacheWidth: 336,
                cacheHeight: 336,
              ),
            ),
            // Amblem üzerinde çapraz prizmatik parıltı taraması
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(sweepBegin, sweepBegin),
                      end: Alignment(sweepEnd, sweepEnd),
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.24),
                        const Color(0xFF7DD3FC).withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.45, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashFullScreenFXPainter extends CustomPainter {
  final double fxPhase;
  final double introProgress;

  const _SplashFullScreenFXPainter({
    required this.fxPhase,
    required this.introProgress,
  });

  static const _particleColors = <Color>[
    Color(0xFF38BDF8),
    Color(0xFFA78BFA),
    Color(0xFFFBBF24),
    Color(0xFF2DD4BF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final maxR = size.longestSide * 0.78;
    final fadeIn = Curves.easeOut.transform(introProgress.clamp(0.0, 1.0));

    // 1. Yumuşak çapraz aurora ışık huzmeleri
    _paintGodRays(canvas, size, center, fadeIn);

    // 2. Tam ekrana yayılan 3 aurora enerji dalgası
    const waveColors = <Color>[
      Color(0xFF38BDF8),
      Color(0xFFA78BFA),
      Color(0xFFFBBF24),
    ];
    for (int i = 0; i < 3; i++) {
      final t = (fxPhase + i / 3.0) % 1.0;
      final radius = 58.0 + (maxR * Curves.easeOutCubic.transform(t));
      final alpha = (1.0 - t) * 0.28 * fadeIn;
      if (alpha <= 0.005) continue;

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0 * (1.0 - t * 0.6)
        ..color = waveColors[i].withValues(alpha: alpha * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(center, radius, glowPaint);

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = waveColors[i].withValues(alpha: alpha);
      canvas.drawCircle(center, radius, ringPaint);
    }

    // 3. Merkez çevresinde çift ters dönen yörünge halkaları
    _paintOrbitalArcs(canvas, center, fadeIn);

    // 4. Tüm ekrana yayılan 32 yükselen ve parıldayan parçacık
    _paintParticles(canvas, size, fadeIn);
  }

  void _paintGodRays(
    Canvas canvas,
    Size size,
    Offset center,
    double fadeIn,
  ) {
    final shift = math.sin(fxPhase * 2 * math.pi) * size.width * 0.14;
    final rayRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-0.9 + shift / size.width, -1.0),
        end: Alignment(0.7 + shift / size.width, 1.0),
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.12 * fadeIn),
          const Color(0xFFA78BFA).withValues(alpha: 0.06 * fadeIn),
          Colors.transparent,
          const Color(0xFFFBBF24).withValues(alpha: 0.08 * fadeIn),
        ],
        stops: const [0.0, 0.34, 0.65, 1.0],
      ).createShader(rayRect);
    canvas.drawRect(rayRect, rayPaint);

    // Merkez arkasında sıcak aurora çekirdek parıltısı
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.24 * fadeIn),
          const Color(0xFF818CF8).withValues(alpha: 0.10 * fadeIn),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.55));
    canvas.drawCircle(center, size.width * 0.55, corePaint);
  }

  void _paintOrbitalArcs(Canvas canvas, Offset center, double fadeIn) {
    final outerRadius = 116.0;
    final innerRadius = 98.0;
    final cwAngle = fxPhase * 2 * math.pi;
    final ccwAngle = -fxPhase * 2 * math.pi * 1.4;

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45 * fadeIn);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.38 * fadeIn);

    for (int k = 0; k < 3; k++) {
      final start = cwAngle + (k * 2 * math.pi / 3);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        start,
        math.pi * 0.38,
        false,
        outerPaint,
      );
    }

    for (int k = 0; k < 2; k++) {
      final start = ccwAngle + (k * math.pi);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        start,
        math.pi * 0.52,
        false,
        innerPaint,
      );
    }
  }

  void _paintParticles(Canvas canvas, Size size, double fadeIn) {
    for (int i = 0; i < 32; i++) {
      // Deterministik dağılım
      final seedX = ((i * 73 + 19) % 100) / 100.0;
      final seedY = ((i * 41 + 7) % 100) / 100.0;
      final speed = 0.35 + ((i * 17) % 10) / 14.0;
      final progress = (seedY - fxPhase * speed) % 1.0;
      final drift = math.sin((fxPhase * 2 * math.pi) + i) * 14.0;

      final x = (seedX * size.width) + drift;
      final y = progress * size.height;
      final radius = 1.4 + ((i * 13) % 5) * 0.55;
      final twinkle = 0.45 + 0.55 * math.sin((fxPhase * 2 * math.pi * 2) + i);
      final alpha = (0.28 + twinkle * 0.48) * fadeIn;
      final color = _particleColors[i % _particleColors.length];

      final halo = Paint()
        ..color = color.withValues(alpha: alpha * 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(x, y), radius * 2.4, halo);

      final dot = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashFullScreenFXPainter oldDelegate) {
    return oldDelegate.fxPhase != fxPhase ||
        oldDelegate.introProgress != introProgress;
  }
}
