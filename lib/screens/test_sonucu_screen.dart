import 'package:flutter/material.dart';
import '../models/question.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/token_widget.dart';
import '../widgets/glass_container.dart';
import '../services/token_service.dart';
import '../services/user_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/quest_service.dart';
import '../services/achievement_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_permission_manager.dart'; // Added for permission handling
import 'dart:ui'; // For BackdropFilter

class TestSonucuScreen extends StatefulWidget {
  final List<Question> questions;
  final List<int?> userAnswers;
  final int score;
  final VoidCallback onRestart;
  final VoidCallback onBackToWelcome;
  final void Function(String difficulty)? onContinueWithDifficulty;
  final String difficulty;
  final String category;
  final bool isOnboarding;
  final bool isDuel;
  final int botScore;
  final String botName;
  final String botAvatar;
  final bool playerFinishedFirst;

  const TestSonucuScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.score,
    required this.onRestart,
    required this.onBackToWelcome,
    this.onContinueWithDifficulty,
    required this.difficulty,
    required this.category,
    this.isOnboarding = false,
    this.isDuel = false,
    this.botScore = 0,
    this.botName = 'Rakip',
    this.botAvatar = 'avatars/avatar_1.jpg',
    this.playerFinishedFirst = false,
  });

  @override
  State<TestSonucuScreen> createState() => _TestSonucuScreenState();
}

class _TestSonucuScreenState extends State<TestSonucuScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  // Gamification state
  int _userLevel = 1;
  int _completedQuizzes = 0;
  int _quizzesForNextLevel = 20;
  int _userRank = 0;
  int _categoryCorrect = 0;
  int _categoryTotal = 0;
  DateTime _resultShownAt = DateTime.now();
  bool _bonusTokenClaimed = false;
  bool _showWelcomeBonusCard = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _orbController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);

    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    _resultShownAt = DateTime.now();
    _awardTokens();
    _puanEkle();
    _levelKontrol();
    _loadGamificationData();
    _recordQuizCompletion();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _loadGamificationData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load user profile for level info
      final profile = await UserService.getUserProfile(user.uid);
      if (profile != null && mounted) {
        final quizzes = profile['completedQuizzes'] ?? 0;
        final level = UserService.calculateLevel(quizzes);
        // Quizzes needed for level L→L+1 is 10*(L+1)+10
        final nextLevelQuizzes = 10 * (level + 1) + 10;
        setState(() {
          _userLevel = level;
          _completedQuizzes = quizzes;
          _quizzesForNextLevel = nextLevelQuizzes;
        });

        // Test sayısı başarımlarını kontrol et
        await AchievementService.checkAndUnlockTestCountAchievements(quizzes, context);
      }

      // İmkansız modda tam puan başarımı kontrol et
      await AchievementService.checkAndUnlockImpossibleMaster(
        widget.difficulty,
        widget.score,
        widget.questions.length,
        context,
      );

      // Load rank
      final rank = await UserService.getUserRank(user.uid, 'Genel');
      if (mounted) setState(() => _userRank = rank);

      // Load category mastery from local DB
      final categoryStats =
          await DatabaseHelper.instance.getCategoryStatsFromTests();
      if (categoryStats.containsKey(widget.category) && mounted) {
        final stats = categoryStats[widget.category]!;
        setState(() {
          _categoryCorrect = stats['correct'] ?? 0;
          _categoryTotal = (stats['correct'] ?? 0) + (stats['wrong'] ?? 0);
        });
      }
    } catch (e) {
      print('Gamification data load error: $e');
    }
  }

  Future<void> _recordQuizCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_quiz_completion', DateTime.now().toIso8601String());
      // Cancel existing re-engagement notifications and schedule new ones
      await NotificationService.cancelReEngagementNotifications();
      await NotificationService.scheduleReEngagementNotifications();

      // Görev ilerlemesini güncelle
      await QuestService.onTestCompleted(
        difficulty: widget.difficulty,
        score: widget.score,
        totalQuestions: widget.questions.length,
        category: widget.category,
      );

      // Yeni kullanıcılar için bildirim iznini (permission) DİREKT BURADA isteyelim
      if (widget.isOnboarding || _completedQuizzes <= 1) {
        // İsteği ekran build edildikten kısa bir süre sonra gösterelim ki göze batsın
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            importNotificationManagerThenCheck();
          }
        });
      }
    } catch (e) {
      print('Quiz completion record error: $e');
    }
  }

  void importNotificationManagerThenCheck() async {
    try {
      // We already have the NotificationPermissionManager imported at top
      await NotificationPermissionManager.notificationPermissions(context);
    } catch (e) {
      print(e);
    }
  }

  int get _maxStreak {
    int currentStreak = 0;
    int maxStreak = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final bool isCorrect = widget.userAnswers.length > i && widget.userAnswers[i] == widget.questions[i].correctIndex;
      if (isCorrect) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }
    return maxStreak;
  }

  int get _comboBonusPoints {
    final katsayilar = {
      'Kolay': 2,
      'Orta': 3,
      'Zor': 4,
      'Imkansız': 6,
    };
    final int katsayi = katsayilar[widget.difficulty] ?? 2;
    int currentStreak = 0;
    double totalMultiplierBonusPoints = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      final bool isCorrect = widget.userAnswers.length > i && widget.userAnswers[i] == widget.questions[i].correctIndex;
      if (isCorrect) {
        currentStreak++;
        double multiplierBonus = 0.0;
        if (currentStreak == 3) {
          multiplierBonus = 0.5;
        } else if (currentStreak == 4) {
          multiplierBonus = 1.0;
        } else if (currentStreak >= 5) {
          multiplierBonus = 1.5;
        }
        totalMultiplierBonusPoints += katsayi * multiplierBonus;
      } else {
        currentStreak = 0;
      }
    }
    return totalMultiplierBonusPoints.round();
  }

  void _puanEkle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final katsayilar = {
      'Kolay': 2,
      'Orta': 3,
      'Zor': 4,
      'Imkansız': 6,
    };

    final int katsayi = katsayilar[widget.difficulty] ?? 1;
    final int basePuan = widget.score * katsayi;
    final int bonusPuan = _comboBonusPoints;
    int totalPuan = basePuan + bonusPuan;
    
    final bool isTie = widget.score == widget.botScore;
    final bool playerWonDuel = widget.isDuel && (widget.score > widget.botScore || (isTie && widget.playerFinishedFirst == true));

    if (playerWonDuel) {
      totalPuan *= 2;
      // Also reward tokens
      await TokenService.awardTokensForDuelWin();
    }

    try {
      await UserService.addPointsToUser(
        uid: user.uid,
        category: widget.category,
        pointsToAdd: totalPuan,
        difficulty: widget.difficulty,
      );
      if (mounted) {
        final String msg = playerWonDuel 
            ? 'duel.won_dialog'.tr()
            : 'result.score_saved'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('result.score_error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _awardTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final bool welcomeBonusGiven = prefs.getBool('welcome_bonus_given') ?? false;

    if (widget.isOnboarding && !welcomeBonusGiven) {
      // Hoşgeldin bonusu (100 Token) sadece ilk sefer verilir
      await prefs.setBool('welcome_bonus_given', true);
      if (mounted) {
        setState(() {
          _showWelcomeBonusCard = true;
        });
      }
      await TokenService.addTokens(100);
    } else {
      await TokenService.awardTokensForQuiz(widget.difficulty, widget.score);
      final bool playerWonDuel = widget.isDuel && (widget.score > widget.botScore);
      if (playerWonDuel) {
        await TokenService.addTokens(50);
      }
    }
  }

  void _levelKontrol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final result = await UserService.incrementCompletedQuizzes(user.uid);
      if (result['levelUp'] == true && mounted) {
        _showLevelUpDialog(result['newLevel'], result['reward']);
      }
    } catch (e) {
      print('Level kontrol hatası: $e');
    }
  }

  void _showLevelUpDialog(int newLevel, int reward) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: GlassContainer(
                  borderRadius: 32,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated star icon with glow
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.3),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.stars_rounded,
                            size: 100,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Animated Level Up Text
                      DefaultTextStyle(
                        style: const TextStyle(
                          fontSize: 32.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              'level_system.level_up'.tr().toUpperCase(),
                              speed: const Duration(milliseconds: 100),
                            ),
                          ],
                          isRepeatingAnimation: false,
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'level_system.level_up_desc'
                            .tr(args: [newLevel.toString()]),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Reward Card with Gradient
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withOpacity(0.2),
                              Colors.amber.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.toll_rounded,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'level_system.level_reward'
                                      .tr(args: [reward.toString()])
                                      .split(':')
                                      .first,
                                  style: TextStyle(
                                    color: Colors.amber.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  '$reward ${'token.unit'.tr()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Ok Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'common.ok'.tr().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _orbAnimation,
          builder: (context, child) => Positioned(
            top: 100 + (20 * _orbAnimation.value),
            left: -30,
            child: _buildOrb(200, const Color(0xFF6366F1).withOpacity(0.2)),
          ),
        ),
        AnimatedBuilder(
          animation: _orbAnimation,
          builder: (context, child) => Positioned(
            bottom: 150 - (30 * _orbAnimation.value),
            right: -50,
            child: _buildOrb(250, const Color(0xFFA855F7).withOpacity(0.15)),
          ),
        ),
      ],
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.6),
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final successRate = (widget.score / widget.questions.length) * 100;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Deep Background
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox.expand(),
          ),
          RepaintBoundary(child: _buildBackgroundOrbs()),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          if (_showWelcomeBonusCard) _buildWelcomeBonusCard(),
                          if (_showWelcomeBonusCard) const SizedBox(height: 24),

                          _buildScoreCircle(successRate),
                          const SizedBox(height: 24),

                          if (widget.isDuel) _buildDuelComparison(),

                          _buildStatsOverview(successRate),
                          const SizedBox(height: 20),

                          _buildContinueCard(successRate),
                          const SizedBox(height: 20),

                          _buildGamificationSection(),
                          const SizedBox(height: 24),

                          _buildResultsSummary(),
                          const SizedBox(height: 100), // Space for bottom area
                        ],
                      ),
                    ),
                  ),
                  _buildStickyBottomArea(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _showWelcomeBonusCard
                  ? "onboarding.welcome_gift".tr()
                  : 'result.title'.tr(),
              style: const TextStyle(
                  fontSize: 24, // Slightly smaller to fit "HOŞGELDİN HEDİYESİ"
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5),
            ),
          ),
          const TokenWidget(),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(double rate) {
    Color color = _getRatingColor(rate);
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.05),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 5)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${rate.toInt()}%',
                style: TextStyle(
                    fontSize: 42, fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                '${widget.score}/${widget.questions.length}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview(double rate) {
    final katsayilar = {
      'Kolay': 2,
      'Orta': 3,
      'Zor': 4,
      'Imkansız': 6,
    };
    final int katsayi = katsayilar[widget.difficulty] ?? 2;
    final int basePuan = widget.score * katsayi;
    final int bonusPuan = _comboBonusPoints;
    final int totalPuan = basePuan + bonusPuan;

    return Column(
      children: [
        Text(
          _getRatingMessage(rate),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                _getRatingColor(rate).withOpacity(0.5),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.95),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'result.correct'.tr(),
                        '${widget.score}',
                        Colors.greenAccent,
                        Icons.check_circle_outline_rounded,
                      ),
                    ),
                    _buildDivider(),
                    Expanded(
                      child: _buildStatItem(
                        'result.wrong'.tr(),
                        '${widget.questions.length - widget.score}',
                        Colors.redAccent,
                        Icons.cancel_outlined,
                      ),
                    ),
                    _buildDivider(),
                    Expanded(
                      child: _buildStatItem(
                        'result.max_combo'.tr(),
                        '$_maxStreak',
                        Colors.orangeAccent,
                        Icons.offline_bolt_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.1), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'result.score'.tr(),
                        '$basePuan',
                        Colors.blueAccent,
                        Icons.stars_outlined,
                      ),
                    ),
                    _buildDivider(),
                    Expanded(
                      child: _buildStatItem(
                        'result.combo_bonus'.tr(),
                        '+$bonusPuan',
                        Colors.amberAccent,
                        Icons.bolt_rounded,
                      ),
                    ),
                    _buildDivider(),
                    Expanded(
                      child: _buildStatItem(
                        'result.total_score'.tr(),
                        '$totalPuan',
                        Colors.indigoAccent,
                        Icons.emoji_events_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Text('result.question_details'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            final userIdx = widget.userAnswers.length > index
                ? widget.userAnswers[index]
                : null;
            final isCorrect = userIdx == q.correctIndex;
            final color = isCorrect ? Colors.greenAccent : Colors.redAccent;
            final String userAnswer =
                userIdx != null ? q.options[userIdx] : 'result.no_answer'.tr();
            final String correctAnswer = q.options[q.correctIndex];

            return Column(
              children: [
                if (index > 0)
                  Divider(color: Colors.white.withOpacity(0.05), height: 1),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(vertical: 4),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: Text('${index + 1}',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold))),
                    ),
                    title: Text(
                      q.question,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    trailing: Icon(
                        isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: color.withOpacity(0.6),
                        size: 20),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Full Question Reveal
                            Text(
                              q.question,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: Colors.white.withOpacity(0.05),
                            ),
                            const SizedBox(height: 12),

                            _buildAnswerDetail(
                                'result.your_answer'.tr(), userAnswer, color),
                            if (!isCorrect) ...[
                              const SizedBox(height: 8),
                              _buildAnswerDetail('result.correct_answer'.tr(),
                                  correctAnswer, Colors.greenAccent),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnswerDetail(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildWelcomeBonusCard() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade600, Colors.orange.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              "onboarding.welcome_gift".tr(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "onboarding.gift_amount".tr(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "onboarding.gift_desc".tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ====== RETENTION FEATURE 1: Post-Quiz Continue Card ======
  Widget _buildContinueCard(double successRate) {
    String emoji;
    String message;
    String buttonText;
    String suggestedDifficulty;

    if (successRate >= 80) {
      emoji = '🔥';
      message = 'retention.great_score'.tr();
      buttonText = 'retention.try_harder'.tr();
      suggestedDifficulty = widget.difficulty == 'Zor' ? 'Imkansız' : 'Zor';
    } else if (successRate >= 50) {
      emoji = '💪';
      message = 'retention.good_start'.tr();
      buttonText = 'retention.master_it'.tr();
      suggestedDifficulty = widget.difficulty;
    } else {
      emoji = '🎯';
      message = 'retention.keep_trying'.tr();
      buttonText = 'retention.try_easier'.tr();
      suggestedDifficulty = widget.difficulty == 'Kolay' ? 'Kolay' : 'Orta';
    }

    final secondsSinceResult =
        DateTime.now().difference(_resultShownAt).inSeconds;
    final showBonus = secondsSinceResult < 120 && !_bonusTokenClaimed;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (showBonus) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'retention.bonus_token'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (showBonus && !_bonusTokenClaimed) {
                  setState(() => _bonusTokenClaimed = true);
                  await TokenService.addTokens(5);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('retention.bonus_earned'.tr()),
                        backgroundColor: Colors.amber.shade700,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
                if (widget.onContinueWithDifficulty != null) {
                  widget.onContinueWithDifficulty!(suggestedDifficulty);
                } else {
                  widget.onRestart();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ).copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== RETENTION FEATURE 2: Gamification Section ======
  Widget _buildGamificationSection() {
    return Column(
      children: [
        _buildLevelProgressCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildCategoryMasteryCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildLeaderboardTeaserCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelProgressCard() {
    // Calculate progress to next level
    final currentLevelThreshold = _userLevel <= 1
        ? 0
        : (5 * _userLevel * _userLevel + 5 * _userLevel - 10);
    final nextLevelThreshold =
        5 * (_userLevel + 1) * (_userLevel + 1) + 5 * (_userLevel + 1) - 10;
    final quizzesInLevel = _completedQuizzes - currentLevelThreshold;
    final quizzesNeeded = nextLevelThreshold - currentLevelThreshold;
    final progress = quizzesNeeded > 0
        ? (quizzesInLevel / quizzesNeeded).clamp(0.0, 1.0)
        : 0.0;
    final remaining = _quizzesForNextLevel - quizzesInLevel;

    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'retention.level'.tr()} $_userLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'retention.quizzes_to_next'.tr(
                          args: [remaining > 0 ? remaining.toString() : '0']),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFFA855F7),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      ),
                      borderRadius: BorderRadius.circular(6),
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

  String _getTranslatedCategory(String cat) {
    switch (cat) {
      case 'Genel':
        return 'categories.general'.tr();
      case 'Genel Kültür':
        return 'categories.general_culture'.tr();
      case 'Yemek Kültürü':
        return 'categories.food'.tr();
      case 'Coğrafya':
        return 'categories.geography'.tr();
      case 'Futbol':
        return 'categories.football'.tr();
      case 'Dini':
        return 'categories.religious'.tr();
      case 'Bilim':
        return 'categories.science'.tr();
      case 'Sinema ve Dizi':
        return 'categories.cinema'.tr();
      case 'Tarih':
        return 'categories.history'.tr();
      case 'Magazin':
        return 'categories.magazine'.tr();
      case 'Müzik':
        return 'categories.music'.tr();
      default:
        return cat; // Fallback
    }
  }

  Widget _buildCategoryMasteryCard() {
    final masteryPercent = _categoryTotal > 0
        ? ((_categoryCorrect / _categoryTotal) * 100).toInt()
        : 0;

    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(
            Icons.school_rounded,
            color: Colors.cyan.shade300,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            '$masteryPercent%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'retention.category_mastery'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _getTranslatedCategory(widget.category),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.cyan.shade300,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTeaserCard() {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: Colors.amber.shade300,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            _userRank > 0 ? '#$_userRank' : '-',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'retention.your_rank'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'retention.climb_higher'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.amber.shade300,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: MyNativeAd(
                height: 120,
                factoryId: 'adFactoryExample',
                refreshInterval: 30,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    label: widget.isOnboarding
                        ? "onboarding.play_again".tr()
                        : 'result.new_test'.tr(),
                    onTap: widget.onRestart,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                    icon: Icons.rocket_launch_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildButton(
                    label: 'result.home'.tr(),
                    onTap: widget.onBackToWelcome,
                    isOutlined: true,
                    icon: Icons.home_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    bool isOutlined = false,
    IconData? icon,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isOutlined
                ? BorderSide(color: Colors.white.withOpacity(0.3))
                : BorderSide.none,
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            color: isOutlined ? Colors.white.withOpacity(0.05) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuelComparison() {
    if (!widget.isDuel) return const SizedBox.shrink();

    final bool isTie = widget.score == widget.botScore;
    final bool playerWonByScore = widget.score > widget.botScore;
    final bool playerWonBySpeed = isTie && widget.playerFinishedFirst == true;
    final bool playerLostBySpeed = isTie && widget.playerFinishedFirst == false;
    final bool playerWon = playerWonByScore || playerWonBySpeed;

    String resultText;
    if (playerWonByScore) {
      resultText = 'duel.won'.tr();
    } else if (playerWonBySpeed) {
      resultText = 'Hızla Kazandın!';
    } else if (playerLostBySpeed) {
      resultText = 'Rakip Daha Hızlı!';
    } else if (isTie) {
      resultText = 'duel.tie'.tr();
    } else {
      resultText = 'duel.lost'.tr();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            playerWon ? Colors.greenAccent : (isTie && !playerLostBySpeed ? Colors.grey : Colors.redAccent),
            Colors.white.withOpacity(0.1),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.95),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          children: [
            Text(
              resultText,
              style: TextStyle(
                color: playerWon ? Colors.greenAccent : (isTie && !playerLostBySpeed ? Colors.white70 : Colors.redAccent),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: const Icon(Icons.person, color: Colors.blueAccent, size: 36),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'duel.you'.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.score}',
                      style: TextStyle(
                        color: playerWon ? Colors.greenAccent : Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'DOĞRU',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: AssetImage(widget.botAvatar),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.botName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.botScore}',
                      style: TextStyle(
                        color: !playerWon && !isTie ? Colors.redAccent : Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'DOĞRU',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(double rate) {
    if (rate >= 80) return Colors.greenAccent;
    if (rate >= 50) return Colors.amberAccent;
    return Colors.redAccent;
  }

  String _getRatingMessage(double rate) {
    if (rate >= 90) return 'result.msg_perfect'.tr();
    if (rate >= 80) return 'result.msg_great'.tr();
    if (rate >= 60) return 'result.msg_good'.tr();
    if (rate >= 40) return 'result.msg_poor'.tr();
    return 'result.msg_fail'.tr();
  }
}
