import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'basari_hesapla_screen.dart';
import 'kategori_screen.dart';
import 'account_screen.dart';
import '../main.dart';
import '../services/update_control.dart';
import '../services/user_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/background_orbs.dart';
import 'tier_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_utils.dart';
import '../services/notification_service.dart';
import '../services/notification_permission_manager.dart';
import 'shop_screen.dart';
import '../widgets/language_selector_button.dart';
import 'language_selection_screen.dart';
import '../services/quest_service.dart';
import '../models/quest.dart';
import '../services/achievement_service.dart';
import '../services/streak_service.dart';
import '../widgets/daily_streak_dialog.dart';
import '../widgets/lucky_wheel_dialog.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onStart;
  final bool skipLoading;
  const WelcomeScreen({
    super.key,
    required this.onStart,
    this.skipLoading = false,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late AnimationController _onboardingController;
  late Animation<double> _pulsingAnimation;

  bool _showOnboardingGuide = false;

  User? currentUser;
  bool _isCheckingAuth = true;
  StreamSubscription<User?>? _authSubscription;
  bool _hasUnseenAchievements = false;

  // Cached user data to avoid unnecessary Firestore refetches
  String? _cachedAvatarPath;
  int _cachedLevel = 1;
  bool _userDataLoaded = false;

  // Streak & Retention states
  int _streakCount = 0;
  bool _canClaimStreak = false;
  bool _canSpinWheel = false;

  Future<void> _checkConsecutiveLogin() async {
    try {
      final streakStatus = await StreakService.checkStreakStatus();
      final canSpin = await LuckyWheelDialog.canSpinToday();

      if (mounted) {
        setState(() {
          _streakCount = streakStatus['streak'] as int;
          _canClaimStreak = streakStatus['canClaimToday'] as bool;
          _canSpinWheel = canSpin;
        });

        if (_canClaimStreak) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted && currentUser != null) {
              DailyStreakDialog.show(
                context,
                currentStreak: _streakCount,
                canClaimToday: _canClaimStreak,
                onClaimed: () {
                  _checkConsecutiveLogin();
                  _loadUserData();
                },
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Streak check error: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Animation controllers
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _onboardingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulsingAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _onboardingController, curve: Curves.easeInOut),
    );

    // Animations
    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.elasticOut,
    ));

    // Auth kontrolü ve zorunlu giriş
    _checkAuthStateAndRedirect();
  }

  void _checkAuthStateAndRedirect() async {
    setState(() {
      _isCheckingAuth = !widget.skipLoading;
    });

    // Önce mevcut auth durumunu kontrol et
    currentUser = FirebaseAuth.instance.currentUser;

    // Auth başarılı ise kontrolleri paralel yap — ANR önleme
    if (currentUser != null) {
      // Tüm bağımsız kontrolleri paralel çalıştır
      await Future.wait([
        _checkAppUpdate(),
        _checkMonthlyWinner(),
        _checkConsecutiveLogin(),
        _loadUserData(),
      ]);

      // Check for first-time guest (depends on currentUser being set)
      if (currentUser!.isAnonymous) {
        try {
          final results = await Future.wait([
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .get(),
            SharedPreferences.getInstance(),
          ]);

          final userDoc = results[0] as DocumentSnapshot;
          final prefs = results[1] as SharedPreferences;
          final totalQuizzes = (userDoc.data()
                  as Map<String, dynamic>?)?['totalQuizzes'] as int? ??
              0;
          final hasSeenOnboarding =
              prefs.getBool('has_seen_onboarding_v2') ?? false;

          if (totalQuizzes == 0 && !hasSeenOnboarding && mounted) {
            // Automatically start the first quiz for new users
            await prefs.setBool('has_seen_onboarding_v2', true);
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const QuizFlow(
                  initialCategory: 'Genel Kültür',
                  initialDifficulty: 'Kolay',
                  initialDuration: 30,
                ),
              ),
            );
          }
        } catch (e) {
          // Silently handle onboarding check failure
        }
      }
    }

    // Kullanıcı giriş yapmışsa, update kontrolü yap ve animasyonları başlat
    setState(() {
      _isCheckingAuth = false;
    });

    if (currentUser != null) {
      // Bildirim izinlerini kontrol et ve planla (SADECE eski kullanıcılar için)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .get();
          final totalQuizzes = (userDoc.data())?['totalQuizzes'] as int? ?? 0;

          // Eğer hiç quiz çözmemişse (yeni kullanıcıysa) Loading ekranında izin İSTEME
          if (totalQuizzes > 0) {
            _checkNotifications();
          }
        } catch (e) {
          // Hata olursa yine de soralım (failsafe)
          _checkNotifications();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkUpdate(context);
    });

    // Auth state changes listener
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          currentUser = user;
        });

        // Eğer kullanıcı çıkış yaparsa, login ekranına yönlendir
        if (user == null) {
          setState(() {
            _isCheckingAuth = true;
          });

          // Hemen yönlendirme yap
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionScreen(),
              ),
            );
          }
        }
      }
    });

    // Start animations (sadece kullanıcı giriş yapmışsa)
    if (currentUser != null) {
      _headerAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _buttonAnimationController.forward();
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;
    try {
      final avatarIndex =
          await UserService.getAvatarIndexFromCurrentUser(currentUser);
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      final data = userDoc.data();
      if (data != null) {
        final tokens = data['tokens'] as int? ?? 50;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_tokens', tokens);
      }
      final hasUnseen = await AchievementService.hasUnseenAchievements();
      if (mounted) {
        setState(() {
          _cachedAvatarPath = (avatarIndex != null && avatarIndex.isNotEmpty)
              ? UserService.getAvatarPath(avatarIndex)
              : null;
          _cachedLevel = data?['level'] ?? 1;
          _hasUnseenAchievements = hasUnseen;
          _userDataLoaded = true;
        });
      }
    } catch (e) {
      // Silently handle — fallback to default icon
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _headerAnimationController.dispose();
    _buttonAnimationController.dispose();
    _onboardingController.dispose();
    super.dispose();
  }

  Widget _buildAuthButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountScreen(),
                ),
              );
              if (mounted) {
                _loadUserData(); // Refresh cached data after returning
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _cachedAvatarPath != null
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey.shade300,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    _cachedAvatarPath!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 16,
                                      );
                                    },
                                  ),
                                ),
                              )
                            : const Icon(Icons.person,
                                color: Colors.white, size: 16),
                        if (_hasUnseenAchievements)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'welcome_screen.my_account'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_userDataLoaded)
                        Text(
                          '${'level_system.level'.tr()} $_cachedLevel',
                          style: TextStyle(
                            color: Colors.amber.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakChip() {
    return GestureDetector(
      onTap: () {
        DailyStreakDialog.show(
          context,
          currentStreak: _streakCount,
          canClaimToday: _canClaimStreak,
          onClaimed: () {
            _checkConsecutiveLogin();
            _loadUserData();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$_streakCount',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelChip() {
    return GestureDetector(
      onTap: () {
        LuckyWheelDialog.show(
          context,
          onSpinCompleted: () {
            _checkConsecutiveLogin();
            _loadUserData();
          },
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎡', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
          if (_canSpinWheel)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedDailyCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade900.withValues(alpha: 0.4),
            Colors.deepOrange.shade800.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QuizFlow(
                  initialCategory: 'Genel Kültür',
                  initialDifficulty: 'Zor',
                  initialDuration: 30,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🚀', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'new_features.special_quiz_of_day'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'new_features.double_points_badge'.tr(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'new_features.hard_mode_extra_token'.tr(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.amber, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rotating Logo
              Hero(
                tag: 'app_logo',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'lib/assets/emilekbul2.png',
                    width: 120,
                    height: 120,
                    cacheWidth: 360, // 120 * 3 for retina/high-density
                    cacheHeight: 360,
                  ),
                ),
              ),
              const SizedBox(height: 34),

              // App Title
              Text(
                'app_title'.tr(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Modern Loading indicator
              Column(
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFE6A141)),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'welcome.loading'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Logo ve diğer varlıkları önbelleğe al
    precacheImage(const AssetImage('lib/assets/emilekbul2.png'), context);
  }

  Future<void> _checkNotifications() async {
    try {
      if (!mounted) return;
      // Önce izin kontrolü (Kullanıcıya dialog gösterebilir)
      await NotificationPermissionManager.notificationPermissions(context);

      // Bildirim planlama işini arka planda, sessizce yapalım (beklemiyoruz)
      NotificationService.rescheduleNotifications().catchError((e) {
        debugPrint("Arkaplan planlama hatası: $e");
      });
    } catch (e) {
      debugPrint("Bildirim izni hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return _buildLoadingScreen();
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
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

          // Sunlight Glow Effect
          Positioned(
            top: -200,
            left: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB75E).withValues(alpha: 0.25),
                    const Color(0xFFFFB75E).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Floating Orbs
          const BackgroundOrbs(),

          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LanguageSelectorButton(),
                          const SizedBox(height: 8),
                          _buildStreakChip(),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildAuthButton(),
                          const SizedBox(height: 8),
                          _buildWheelChip(),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo Section
                          SlideTransition(
                            position: _headerSlideAnimation,
                            child: FadeTransition(
                              opacity: _headerFadeAnimation,
                              child: Hero(
                                tag: 'app_logo',
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        blurRadius: 40,
                                        spreadRadius: 5,
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
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title Section
                          SlideTransition(
                            position: _headerSlideAnimation,
                            child: FadeTransition(
                              opacity: _headerFadeAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    'app_title'.tr(),
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  GlassContainer(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 8),
                                    borderRadius: 30,
                                    opacity: 0.1,
                                    child: Text(
                                      'welcome_screen.app_subtitle'.tr(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),

                          // Main Actions
                          ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                                children: [
                                  if (_showOnboardingGuide)
                                    FadeTransition(
                                      opacity: _headerFadeAnimation,
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons
                                                .keyboard_double_arrow_down_rounded,
                                            color:
                                                Colors.white.withValues(alpha: 0.8),
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE6A141)
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              'welcome.onboarding_tip'.tr(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  AnimatedBuilder(
                                    animation: _pulsingAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _showOnboardingGuide
                                            ? _pulsingAnimation.value
                                            : 1.0,
                                        child: child,
                                      );
                                    },
                                    child: StartButton(
                                      onPressed: widget.onStart,
                                      onPressedd:
                                          (category, difficulty, duration,
                                              {bool isDuel = false}) async {
                                        final prefs = await SharedPreferences
                                            .getInstance();
                                        final offlineTaken = prefs.getInt(
                                                'offline_tests_taken') ??
                                            0;

                                        if (offlineTaken >= 10) {
                                          final hasInternet = await AppUtils
                                              .hasInternetConnection();
                                          if (!hasInternet) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'errors.no_internet_ai'
                                                          .tr()),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                  duration: const Duration(
                                                      seconds: 3),
                                                ),
                                              );
                                            }
                                            return;
                                          }
                                        }

                                        if (_showOnboardingGuide) {
                                          setState(() =>
                                              _showOnboardingGuide = false);
                                          await prefs.setBool(
                                              'has_seen_onboarding_v2', true);
                                        }
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => QuizFlow(
                                                initialCategory: category,
                                                initialDifficulty: difficulty,
                                                initialDuration: duration,
                                              ),
                                            ),
                                          );
                                        });
                                      },
                                      text: 'welcome.start_button'.tr(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Secondary Actions
                          // Secondary Actions
                          ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: BasariButton(
                                              onStart: widget.onStart)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: TierListButton(
                                              onPressed: widget.onStart)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFeaturedDailyCard(),
                                  const SizedBox(height: 12),
                                  _buildShopButton(),
                                  const SizedBox(height: 16),
                                  QuestsPanel(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
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

  Future<void> _checkAppUpdate() async {
    await checkUpdate(context);
  }

  Future<void> _checkMonthlyWinner() async {
    try {
      final now = DateTime.now();
      // Her ayın ilk 3 günü kontrol et
      if (now.day <= 3) {
        final prevMonthDate = DateTime(now.year, now.month - 1);
        final yearMonth =
            "${prevMonthDate.year}_${prevMonthDate.month.toString().padLeft(2, '0')}";

        // 1. Kazanan Henüz Belirlenmediyse (Sadece database'e kaydetme işlemi)
        Map<String, dynamic>? winnerData =
            await UserService.getMonthlyWinnerData(yearMonth);

        if (winnerData == null) {
          // Geçen ayın en yüksek puanını alan kişiyi bul (Artık monthly_scores koleksiyonundan)
          // NOT: Bu metodun UserService'e eklenmesi gerekebilir veya manuel sorgu
          // Şimdilik getTopUser metodunun önceki ay parametresini alacak şekilde güncellenmesi lazım
          // Ancak UserService'i karmaşıklaştırmamak için basit bir sorgu yapalım.

          final prevMonthRef = FirebaseFirestore.instance
              .collection('monthly_scores')
              .doc(yearMonth)
              .collection('scores');

          final querySnapshot = await prevMonthRef
              .orderBy('totalPoints', descending: true)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final topUserDoc = querySnapshot.docs.first;
            final topUserData = topUserDoc.data();

            // Lideri kaydet
            await UserService.recordMonthlyWinner(yearMonth, {
              'uid': topUserData['uid'] ?? topUserDoc.id,
              'username': topUserData['username'] ?? 'Bilinmeyen',
              'score': topUserData['totalPoints'] ?? 0,
              'avatarIndex': topUserData['avatarIndex'] ?? '0',
            });

            // Ödülü ver
            await UserService.giveReward(
                topUserData['uid'] ?? topUserDoc.id, 500);
          }
        }

        // 2. Kullanıcıya Göster (Eğer kazanan bu kullanıcıysa veya sadece bilgi vermek istiyorsanız)
        // Burada logic aynı kalabilir, sadece scoresReset kontrolüne gerek yok.
        final winner = await UserService.getLastMonthWinner();
        if (winner != null && winner['month'] == yearMonth) {
          final prefs = await SharedPreferences.getInstance();
          final hasSeen = prefs.getBool('seen_winner_$yearMonth') ?? false;

          // Eğer henüz görmediyse göster
          if (!hasSeen && mounted) {
            _showWinnerDialog(winner);
            // Bir kere gösterdikten sonra işaretle
            await prefs.setBool('seen_winner_$yearMonth', true);
          }
        }
      }
    } catch (e) {
      debugPrint('Monthly winner check error: $e');
    }
  }

  Widget _buildShopButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ShopScreen()),
        );
      },
      child: SizedBox(
        width: double.infinity,
        child: GlassContainer(
          borderRadius: 20,
          opacity: 0.15,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              const Icon(Icons.shopping_bag_rounded,
                  color: Colors.amber, size: 22),
              const SizedBox(height: 4),
              Text(
                'welcome_screen.shop'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWinnerDialog(Map<String, dynamic> winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'welcome_screen.month_champion'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'welcome_screen.chamption_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 24),
              Text(
                AppUtils.localizeUsername(winner['username']),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${winner['score']} ${'welcome_screen.points'.tr()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '+500 ${'welcome_screen.token_earned'.tr()}',
                      style: const TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('welcome_screen.congrats'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TierListButton extends StatelessWidget {
  final VoidCallback onPressed;
  const TierListButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.1,
      blur: 10,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PuanlarEkrani(),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700), size: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "welcome_screen.leaderboard".tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StartButton extends StatelessWidget {
  final VoidCallback onPressed;
  final void Function(String, String, int, {bool isDuel}) onPressedd;
  final String text;

  const StartButton({
    required this.onPressedd,
    required this.onPressed,
    this.text = 'Quiz',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6A141).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => KategoriScreen(
                      onStartQuiz: onPressedd, onStart: onPressed),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BasariButton extends StatelessWidget {
  final VoidCallback onStart;
  const BasariButton({required this.onStart, super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.1,
      blur: 10,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BasariHesaplaScreen(onStart: onStart),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded,
                  color: Colors.blueAccent, size: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'welcome_screen.my_tests'.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuestsPanel extends StatefulWidget {
  const QuestsPanel({super.key});

  @override
  State<QuestsPanel> createState() => _QuestsPanelState();
}

class _QuestsPanelState extends State<QuestsPanel> {
  List<Quest> _quests = [];
  bool _isLoading = true;
  String _activeTab = 'daily'; // 'daily' or 'weekly'

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    try {
      await QuestService.initializeQuests();
      final quests = await QuestService.getActiveQuests();
      if (mounted) {
        setState(() {
          _quests = quests;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Quests load error: $e');
    }
  }

  Future<void> _claimReward(String questId) async {
    try {
      final success = await QuestService.claimQuestReward(questId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('quests.reward_claimed'.tr()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadQuests();
      }
    } catch (e) {
      debugPrint('Claim reward error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    final filteredQuests = _quests.where((q) => q.type == _activeTab).toList();

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amberAccent, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'quests.title'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Tab buttons
              Row(
                children: [
                  _buildTabButton('daily', 'quests.daily'.tr()),
                  const SizedBox(width: 8),
                  _buildTabButton('weekly', 'quests.weekly'.tr()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredQuests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text(
                  'quests.empty'.tr(),
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: filteredQuests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final quest = filteredQuests[index];
                return _buildQuestItem(quest);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.amberAccent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isActive ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.amberAccent : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestItem(Quest quest) {
    final bool isCompleted = quest.currentProgress >= quest.targetProgress;
    final progressVal =
        (quest.currentProgress / quest.targetProgress).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted && !quest.isClaimed
              ? Colors.amberAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? (quest.isClaimed
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.1))
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted
                  ? (quest.isClaimed
                      ? Icons.check_circle_outline_rounded
                      : Icons.star_rounded)
                  : Icons.bolt_rounded,
              color: isCompleted
                  ? (quest.isClaimed ? Colors.greenAccent : Colors.amberAccent)
                  : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QuestService.getQuestTitle(quest.id),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration:
                        quest.isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressVal,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.greenAccent : Colors.amberAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quest.currentProgress}/${quest.targetProgress}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action Button / Reward Badge
          _buildQuestAction(quest, isCompleted),
        ],
      ),
    );
  }

  Widget _buildQuestAction(Quest quest, bool isCompleted) {
    if (quest.isClaimed) {
      return Text(
        'quests.claimed'.tr().toUpperCase(),
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (isCompleted) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: Colors.amberAccent.withValues(alpha: 0.4),
        ),
        onPressed: () => _claimReward(quest.id),
        child: Text(
          'quests.claim'.tr(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${quest.rewardTokens}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.generating_tokens_outlined,
            color: Colors.amberAccent,
            size: 14,
          ),
        ],
      ),
    );
  }
}
