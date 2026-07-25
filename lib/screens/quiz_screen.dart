import 'package:emilekbul/models/question.dart';
import 'package:emilekbul/models/test_result.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:emilekbul/services/token_service.dart';
import '../models/category_model.dart';
import '../services/sound_service.dart';
import '../services/performance_service.dart';
import '../constants/app_categories.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:ui'; // For BackdropFilter
import 'dart:math' as math;

class QuizScreen extends StatefulWidget {
  final List<Question> questions;
  final String category;
  final String difficulty;
  final int duration;
  final bool isDuel;
  final void Function(
    List<int?> userAnswers,
    int score, {
    int? botScore,
    String? botName,
    String? botAvatar,
    bool? playerFinishedFirst,
  }) onFinished;

  const QuizScreen({
    super.key,
    required this.questions,
    required this.category,
    required this.difficulty,
    required this.duration,
    this.isDuel = false,
    required this.onFinished,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int? _selectedIndex;
  late List<int?> _userAnswers;
  late AnimationController _animationController;
  late List<Animation<double>> _optionAnimations;
  late final ValueNotifier<int> _remainingSeconds;
  Timer? _timer;
  final List<int> _eliminatedOptions = [];
  bool _testFinished = false;
  final ScrollController _scrollController = ScrollController();

  // New Joker States
  bool _isDoubleAnswerActive = false;
  bool _isDoubleAnswerUsedInCurrentQuestion = false;
  bool _isFiftyFiftyUsedInCurrentQuestion = false;
  bool _isTransitioning = false;
  bool _isShowingAnswer = false;
  int _userTokens = 0;

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  // Combo States
  int _correctStreak = 0;
  int _maxStreak = 0;
  late AnimationController _comboController;
  late Animation<double> _comboScaleAnimation;
  late Animation<double> _comboOpacityAnimation;
  bool _showComboPopup = false;
  int _comboTriggerValue = 0;

  // Duel & Bot Simulation States
  int _playerScore = 0;
  int _botCurrentIndex = 0;
  int _botScore = 0;
  Timer? _botTimer;
  String _botName = 'Rakip';
  String _botAvatar = 'avatars/avatar_1.jpg';

  // Enhanced Duel States
  bool _botCompleted = false;
  bool _playerFinishedFirst = false;
  bool _botIsThinking = false; // bot currently computing an answer
  bool _botJustAnswered = false; // flash when bot answers
  DateTime? _playerFinishTime;
  DateTime? _botFinishTime;

  // Overlay banner queue
  final List<Map<String, dynamic>> _duelBannerQueue = [];
  bool _duelBannerVisible = false;
  String _duelBannerText = '';
  Color _duelBannerColor = Colors.redAccent;
  IconData _duelBannerIcon = Icons.bolt;
  late AnimationController _bannerController;
  late Animation<Offset> _bannerSlide;
  late Animation<double> _bannerFade;

  @override
  void initState() {
    super.initState();
    _userAnswers = List.filled(widget.questions.length, null);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _orbController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );

    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    if (!PerformanceService.isPerformanceMode) {
      _orbController.repeat(reverse: true);
    }

    _comboController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _comboScaleAnimation = Tween<double>(begin: 0.3, end: 1.3).animate(
      CurvedAnimation(parent: _comboController, curve: Curves.elasticOut),
    );

    _comboOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_comboController);

    _remainingSeconds = ValueNotifier(widget.duration);

    // Overlay banner animation controller
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bannerController, curve: Curves.easeOutBack));
    _bannerFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _bannerController, curve: Curves.easeIn));

    _loadUserTokens();
    _setupOptionAnimations();
    _animationController.forward();
    _startTimer();

    if (widget.isDuel) {
      _startBotSimulation();
    }
  }

  Future<void> _loadUserTokens() async {
    try {
      final tokens = await TokenService.getTokenAmount();
      if (mounted) {
        setState(() {
          _userTokens = tokens;
        });
      }
    } catch (e) {
      print("Token load error: $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds.value = widget.duration;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds.value > 0) {
        _remainingSeconds.value--;
        if (_remainingSeconds.value == 6) {
          SoundService.startClockTick();
        }
      } else {
        _timer?.cancel();
        SoundService.stopClockTick();
        _onTimeExpired();
      }
    });
  }

  void _onTimeExpired() {
    _goNext();
  }

  void _setupOptionAnimations() {
    final optionsLength = widget.questions[_currentIndex].options.length;
    _optionAnimations = List.generate(optionsLength, (index) {
      final startTime = 0.1 * index;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            startTime.clamp(0.0, 1.0),
            1.0,
            curve: Curves.easeOutBack,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _orbController.dispose();
    _comboController.dispose();
    _bannerController.dispose();
    _timer?.cancel();
    _botTimer?.cancel();
    SoundService.stopClockTick();
    _remainingSeconds.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startBotSimulation() {
    if (!widget.isDuel) return;

    final botNames = [
      'ZekaKüpü', 'SoruUstası', 'BilgiAvcısı',
      'AkılKüpü', 'DahiBot', 'EfsaneKayıp', 'QuizMaster'
    ];
    final botAvatars = [
      'avatars/avatar_1.jpg', 'avatars/avatar_2.jpg',
      'avatars/avatar_3.jpg', 'avatars/avatar_4.jpg', 'avatars/avatar_5.jpg'
    ];
    final random = math.Random();

    _botName = botNames[random.nextInt(botNames.length)];
    _botAvatar = botAvatars[random.nextInt(botAvatars.length)];

    // Mark bot as thinking immediately
    if (mounted) setState(() => _botIsThinking = true);
    _scheduleNextBotAnswer();
  }

  void _scheduleNextBotAnswer() {
    if (_botCurrentIndex >= widget.questions.length) return;
    if (_botCompleted) return;

    final random = math.Random();

    // Difficulty-based timing ranges (milliseconds for finer control)
    int minMs = 9000;
    int maxMs = 20000;
    double accuracy = 0.50;

    switch (widget.difficulty) {
      case 'Orta':
        minMs = 6000; maxMs = 14000; accuracy = 0.68; break;
      case 'Zor':
        minMs = 3500; maxMs = 9000; accuracy = 0.82; break;
      case 'İmkansız':
      case 'Imkansız':
        minMs = 2000; maxMs = 6000; accuracy = 0.90; break;
    }

    // Add ±30% jitter — sometimes surprisingly fast, sometimes slow
    final baseMs = minMs + random.nextInt(maxMs - minMs + 1);
    final jitter = (baseMs * 0.30 * (random.nextDouble() * 2 - 1)).toInt();
    final finalMs = (baseMs + jitter).clamp(1500, maxMs + 3000);

    _botTimer = Timer(Duration(milliseconds: finalMs), () {
      if (!mounted || _botCompleted) return;

      final isCorrect = random.nextDouble() < accuracy;

      setState(() {
        if (isCorrect) _botScore++;
        _botCurrentIndex++;
        _botJustAnswered = true;
        _botIsThinking = false;
      });

      // Flash effect resets after 600ms
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _botJustAnswered = false);
      });

      if (_botCurrentIndex < widget.questions.length) {
        // Show overlay banner
        _showDuelBanner(
          'duel.bot_answered'.tr(args: [_botName]),
          Colors.orangeAccent,
          Icons.bolt_rounded,
        );
        // Bot starts thinking on next question
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_botCompleted) setState(() => _botIsThinking = true);
        });
        _scheduleNextBotAnswer();
      } else {
        // Bot finished the test
        _botFinishTime = DateTime.now();
        setState(() {
          _botCompleted = true;
          _botIsThinking = false;
          if (_playerFinishTime == null) {
            // Player hasn't finished yet — bot wins on speed if test not done
            _playerFinishedFirst = false;
          }
        });
        _showDuelBanner(
          'duel.bot_finished_first'.tr(),
          Colors.redAccent,
          Icons.flag_rounded,
          duration: 3000,
        );
      }
    });
  }

  /// Shows an animated overlay banner at the top of the screen.
  void _showDuelBanner(String text, Color color, IconData icon, {int duration = 2000}) {
    _duelBannerQueue.add({'text': text, 'color': color, 'icon': icon, 'duration': duration});
    if (!_duelBannerVisible) {
      _processNextBanner();
    }
  }

  void _processNextBanner() {
    if (_duelBannerQueue.isEmpty || !mounted) {
      if (mounted) setState(() => _duelBannerVisible = false);
      return;
    }

    final next = _duelBannerQueue.removeAt(0);
    setState(() {
      _duelBannerVisible = true;
      _duelBannerText = next['text'] as String;
      _duelBannerColor = next['color'] as Color;
      _duelBannerIcon = next['icon'] as IconData;
    });

    _bannerController.forward(from: 0).then((_) {
      final dur = next['duration'] as int;
      Future.delayed(Duration(milliseconds: dur), () {
        if (!mounted) return;
        _bannerController.reverse().then((_) {
          _processNextBanner();
        });
      });
    });
  }


  Future<bool> _checkTokens(int cost) async {
    final currentTokens = await TokenService.getTokenAmount();
    if (currentTokens < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('quiz.not_enough_tokens'.tr(args: [cost.toString()])),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return false;
    }
    await TokenService.spendTokens(cost);
    await _loadUserTokens();
    return true;
  }

  void _useFiftyFifty() async {
    if (_isFiftyFiftyUsedInCurrentQuestion) return;
    if (!(await _checkTokens(3))) return;

    final currentQuestion = widget.questions[_currentIndex];
    final wrongOptions = <int>[];

    for (int i = 0; i < currentQuestion.options.length; i++) {
      if (i != currentQuestion.correctIndex &&
          !_eliminatedOptions.contains(i)) {
        wrongOptions.add(i);
      }
    }

    if (wrongOptions.length >= 2) {
      wrongOptions.shuffle();
      if (mounted) {
        setState(() {
          _eliminatedOptions.add(wrongOptions[0]);
          _eliminatedOptions.add(wrongOptions[1]);
          _isFiftyFiftyUsedInCurrentQuestion = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('quiz.used_5050'.tr()),
            backgroundColor: Colors.indigoAccent,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _useDoubleAnswer() async {
    if (_isDoubleAnswerUsedInCurrentQuestion) return;
    if (!(await _checkTokens(3))) return;

    if (mounted) {
      setState(() {
        _isDoubleAnswerActive = true;
        _isDoubleAnswerUsedInCurrentQuestion = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('quiz.active_double'.tr()),
          backgroundColor: Colors.blueAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _useSkipQuestion() async {
    if (!(await _checkTokens(6))) return;

    _selectedIndex = widget.questions[_currentIndex].correctIndex;
    _goNext();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('quiz.used_skip'.tr()),
          backgroundColor: Colors.greenAccent,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _onOptionSelected(int index) {
    if (_eliminatedOptions.contains(index)) return;

    // If double answer is active and user picks wrong option
    if (_isDoubleAnswerActive &&
        index != widget.questions[_currentIndex].correctIndex) {
      setState(() {
        _eliminatedOptions.add(index);
        _isDoubleAnswerActive = false; // Used its one chance
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('quiz.shield_active'.tr()),
          backgroundColor: Colors.orangeAccent,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _goNext() {
    if (_isShowingAnswer) return;

    _timer?.cancel();
    SoundService.stopClockTick();

    final currentQuestion = widget.questions[_currentIndex];
    final bool isCorrect = _selectedIndex == currentQuestion.correctIndex;

    setState(() {
      _isShowingAnswer = true;
    });

    if (isCorrect) {
      SoundService.playCorrect();
      _correctStreak++;
      _playerScore++;
      if (_correctStreak > _maxStreak) {
        _maxStreak = _correctStreak;
      }

      if (_correctStreak >= 3) {
        setState(() {
          _comboTriggerValue = _correctStreak;
          _showComboPopup = true;
        });
        _comboController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _showComboPopup = false;
            });
          }
        });
      }
    } else {
      SoundService.playWrong();
      _correctStreak = 0;
    }

    _userAnswers[_currentIndex] = _selectedIndex;

    // Sonucu göstermek için 1.5 saniye bekle
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentIndex < widget.questions.length - 1) {
        // Step 1: Start transition and increment index IMMEDIATELY
        // This allows the next MyNativeAd to start loading in background
        setState(() {
          _isTransitioning = true;
          _currentIndex++;
          _selectedIndex = null;
          _isShowingAnswer = false;
          _eliminatedOptions.clear();
          _isDoubleAnswerActive = false;
          _isDoubleAnswerUsedInCurrentQuestion = false;
          _isFiftyFiftyUsedInCurrentQuestion = false;
        });

        // Step 2: Wait for transition duration
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (!mounted) return;

          // Step 3: Hide overlay and start question animations/timer
          setState(() {
            _isTransitioning = false;
          });

          _animationController.reset();
          _setupOptionAnimations();
          _animationController.forward();
          _startTimer();

          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        _finishTest();
      }
    });
  }

  Future<void> _finishTest() async {
    if (_testFinished) return;
    setState(() => _testFinished = true);

    int score = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_userAnswers[i] == widget.questions[i].correctIndex) {
        score++;
      }
    }

    final testResult = TestResult(
      category: widget.category,
      difficulty: widget.difficulty,
      score: score,
      date: DateTime.now(),
      questions: widget.questions.asMap().entries.map((e) {
        final idx = e.key;
        final q = e.value;
        final user = _userAnswers[idx];
        return TestQuestionDetail(
          testId: 0,
          question: q.question,
          userAnswer: user != null ? q.options[user] : 'Cevaplanmadı',
          correctAnswer: q.options[q.correctIndex],
          options: q.options,
        );
      }).toList(),
    );
    await DatabaseHelper.instance.createTest(testResult);
    if (widget.isDuel) {
      // Determine finish order
      _playerFinishTime = DateTime.now();
      final bool finishedFirst = !_botCompleted;
      if (finishedFirst) {
        _playerFinishedFirst = true;
        _showDuelBanner(
          'duel.player_finished_first'.tr(),
          Colors.greenAccent,
          Icons.emoji_events_rounded,
          duration: 2500,
        );
        await Future.delayed(const Duration(milliseconds: 800));
      }
      widget.onFinished(
        _userAnswers,
        score,
        botScore: _botScore,
        botName: _botName,
        botAvatar: _botAvatar,
        playerFinishedFirst: _playerFinishedFirst,
      );
    } else {
      widget.onFinished(_userAnswers, score);
    }
  }

  void _showFinishEarlyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('quiz.dialog_finish_title'.tr(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('quiz.dialog_finish_msg'.tr(),
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('quiz.dialog_no'.tr(),
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finishTest();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text('quiz.dialog_yes'.tr(),
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return RepaintBoundary(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _orbAnimation,
            builder: (context, child) => Positioned(
              top: 50 + (30 * _orbAnimation.value),
              right: -50,
              child: _buildOrb(250, const Color(0xFF6366F1).withOpacity(0.15)),
            ),
          ),
          AnimatedBuilder(
            animation: _orbAnimation,
            builder: (context, child) => Positioned(
              bottom: 100 - (40 * _orbAnimation.value),
              left: -80,
              child: _buildOrb(300, const Color(0xFFA855F7).withOpacity(0.1)),
            ),
          ),
        ],
      ),
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
            color,
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B1120), Color(0xFF1E293B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SizedBox.expand(),
          ),
          RepaintBoundary(child: _buildBackgroundOrbs()),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _buildTopBar(progress),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildTimerAndTokens(),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 0),
                              child: Column(
                                children: [
                                  const SizedBox(height: 6),
                                  _buildQuestionCard(currentQuestion),
                                  const SizedBox(height: 14),
                                  _buildQuickJokersRow(),
                                  const SizedBox(height: 14),
                                  _buildOptionsList(currentQuestion),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Transition overlay only covers the top area, ad stays visible below
                      if (_isTransitioning)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _isTransitioning ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: ClipRect(
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  color:
                                      const Color(0xFF0F172A).withOpacity(0.7),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration:
                                              const Duration(milliseconds: 800),
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: 0.8 + (value * 0.2),
                                              child: Opacity(
                                                opacity: value,
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white
                                                  .withOpacity(0.05),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.1),
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.psychology_outlined,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                        Text(
                                          'quiz.question_loading'.tr(args: [
                                            (_currentIndex + 1).toString()
                                          ]),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 500),
                                          child: Text(
                                            'quiz.preparing_${((_currentIndex) % 5) + 1}'
                                                .tr(),
                                            key: ValueKey(_currentIndex),
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              fontSize: 15,
                                              fontStyle: FontStyle.italic,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: MyNativeAd(
                    height: 80,
                    factoryId: 'adFactorySmall',
                    refreshInterval: 30,
                  ),
                ),
                _buildBottomAction(),
                const SizedBox(height: 4),
              ],
            ),
          ),
          if (_showComboPopup)
            Center(
              child: FadeTransition(
                opacity: _comboOpacityAnimation,
                child: ScaleTransition(
                  scale: _comboScaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.amberAccent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Colors.amberAccent,
                          size: 60,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_comboTriggerValue COMBO!',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.amberAccent,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.orange,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_comboTriggerValue >= 5) ? "2.5x" : (_comboTriggerValue == 4) ? "2.0x" : "1.5x"} PUAN ÇARPANI!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  Widget _buildTopBar(double progress) {
    if (widget.isDuel) {
      final double playerProgress =
          (_currentIndex + 1) / widget.questions.length;
      final double botProgress =
          (_botCurrentIndex / widget.questions.length).clamp(0.0, 1.0);

      // Score difference badge
      final int diff = _playerScore - _botScore;
      String diffText;
      Color diffColor;
      if (diff > 0) {
        diffText = 'duel.score_diff_ahead'.tr(args: [diff.toString()]);
        diffColor = Colors.greenAccent;
      } else if (diff < 0) {
        diffText = 'duel.score_diff_behind'.tr(args: [diff.abs().toString()]);
        diffColor = Colors.redAccent;
      } else {
        diffText = 'duel.score_tie_label'.tr();
        diffColor = Colors.amberAccent;
      }

      // Status text
      String statusText = 'duel.status_equal'.tr();
      Color statusColor = Colors.amberAccent;
      if (_playerScore > _botScore) {
        statusText = 'duel.status_player_leading'.tr();
        statusColor = Colors.greenAccent;
      } else if (_botScore > _playerScore) {
        statusText = 'duel.status_bot_leading'.tr();
        statusColor = Colors.redAccent;
      } else {
        if (_currentIndex > _botCurrentIndex) {
          statusText = 'duel.status_player_faster'.tr();
          statusColor = Colors.blueAccent;
        } else if (_botCurrentIndex > _currentIndex) {
          statusText = 'duel.status_bot_faster'.tr();
          statusColor = Colors.orangeAccent;
        }
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          children: [
            Row(
              children: [
                // ── Player Side ──
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blueAccent,
                          child: const Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'duel.you'.tr(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_currentIndex + 1}/${widget.questions.length}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_playerScore',
                          style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Center VS + diff badge ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      const Text('VS',
                          style: TextStyle(
                              color: Colors.white30,
                              fontWeight: FontWeight.w900,
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: diffColor.withOpacity(0.4), width: 0.5),
                        ),
                        child: Text(
                          diffText,
                          style: TextStyle(
                              color: diffColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bot Side ──
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _botJustAnswered
                          ? Colors.orangeAccent.withOpacity(0.25)
                          : Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _botJustAnswered
                            ? Colors.orangeAccent.withOpacity(0.6)
                            : Colors.redAccent.withOpacity(0.4),
                        width: _botJustAnswered ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$_botScore',
                          style: TextStyle(
                              color: _botJustAnswered ? Colors.orangeAccent : Colors.redAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _botName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Thinking indicator OR question progress
                              _botIsThinking
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _ThinkingDots(color: Colors.orangeAccent),
                                      ],
                                    )
                                  : Text(
                                      _botCompleted
                                          ? '🏁 Done'
                                          : '${(_botCurrentIndex).clamp(0, widget.questions.length)}/${widget.questions.length}',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.55),
                                          fontSize: 10),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: AssetImage(_botAvatar),
                            ),
                            if (_botIsThinking)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.orangeAccent.withOpacity(0.8),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Race Track ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'duel.race_track'.tr(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Container(
                          key: ValueKey(statusText),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.35), width: 0.5),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const avatarSize = 24.0;
                      final double trackWidth = constraints.maxWidth - avatarSize;
                      final double playerOffset = playerProgress.clamp(0.0, 1.0) * trackWidth;
                      final double botOffset = botProgress.clamp(0.0, 1.0) * trackWidth;

                      return SizedBox(
                        height: 44,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // Player track bg
                            Positioned(
                              top: 9, left: 12, right: 12,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Player track fill
                            Positioned(
                              top: 9, left: 12,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                height: 3,
                                width: playerOffset,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withOpacity(0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Bot track bg
                            Positioned(
                              bottom: 9, left: 12, right: 12,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Bot track fill (pulsing when thinking)
                            Positioned(
                              bottom: 9, left: 12,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                height: 3,
                                width: botOffset,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _botIsThinking
                                        ? [Colors.orangeAccent, Colors.amber]
                                        : [Colors.redAccent, Colors.orangeAccent],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.35),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Player avatar node
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 500),
                              left: playerOffset,
                              top: 0,
                              child: Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.blueAccent, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.blueAccent.withOpacity(0.4),
                                        blurRadius: 6),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundColor: const Color(0xFF0F172A),
                                  child: Text(
                                    '$_playerScore',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Bot avatar node
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 500),
                              left: botOffset,
                              bottom: 0,
                              child: Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _botJustAnswered
                                        ? Colors.orangeAccent
                                        : Colors.redAccent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundImage: AssetImage(_botAvatar),
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
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  () {
                    final categoryItem = AppCategories.categories.firstWhere(
                      (c) => c.name == widget.category,
                      orElse: () => CategoryItem(
                        name: widget.category,
                        icon: Icons.category,
                        color: Colors.grey,
                        description: '',
                        descriptionKey: '',
                        key: '',
                      ),
                    );
                    return Text(
                      categoryItem.key.isEmpty
                          ? categoryItem.name
                          : categoryItem.key.tr(),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1),
                    );
                  }(),
                  const SizedBox(height: 4),
                  Text(
                    'quiz.question_progress'.tr(args: [
                      (_currentIndex + 1).toString(),
                      widget.questions.length.toString()
                    ]),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showFinishEarlyDialog(context),
                child: GlassContainer(
                  borderRadius: 12,
                  opacity: 0.1,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text('quiz.finish'.tr(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress Bar
          Stack(
            children: [
              Container(
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(3))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 6,
                width: (MediaQuery.of(context).size.width - 40) * progress,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerAndTokens() {
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _remainingSeconds,
            builder: (context, seconds, _) {
              return GlassContainer(
                borderRadius: 16,
                opacity: 0.1,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined,
                        color: seconds < 5
                            ? Colors.redAccent
                            : Colors.indigoAccent,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '00:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: seconds < 5 ? Colors.redAccent : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        GlassContainer(
          borderRadius: 16,
          opacity: 0.1,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('$_userTokens',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickJokersRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuickJokerButton(
          icon: Icons.exposure_minus_2_rounded,
          title: 'quiz.joker_5050'.tr(),
          cost: 3,
          color: const Color(0xFF6366F1),
          onTap: _useFiftyFifty,
          isUsed: _isFiftyFiftyUsedInCurrentQuestion,
          isEnabled: _userTokens >= 3,
        ),
        _buildQuickJokerButton(
          icon: Icons.security_rounded,
          title: 'quiz.joker_double'.tr(),
          cost: 3,
          color: const Color(0xFF3B82F6),
          onTap: _useDoubleAnswer,
          isUsed: _isDoubleAnswerUsedInCurrentQuestion,
          isEnabled: _userTokens >= 3,
        ),
        _buildQuickJokerButton(
          icon: Icons.skip_next_rounded,
          title: 'quiz.joker_skip'.tr(),
          cost: 6,
          color: const Color(0xFF10B981),
          onTap: _useSkipQuestion,
          isUsed: false,
          isEnabled: _userTokens >= 6,
        ),
      ],
    );
  }

  Widget _buildQuickJokerButton({
    required IconData icon,
    required String title,
    required int cost,
    required Color color,
    required VoidCallback onTap,
    required bool isUsed,
    required bool isEnabled,
  }) {
    final bool canTap = isEnabled && !isUsed && !_isTransitioning && !_isShowingAnswer;
    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: Opacity(
        opacity: canTap ? 1.0 : (isUsed ? 0.5 : 0.25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUsed
                          ? Colors.grey.withOpacity(0.3)
                          : color.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: canTap
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.15),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    isUsed ? Icons.check_rounded : icon,
                    color: isUsed ? Colors.greenAccent : color,
                    size: 24,
                  ),
                ),
                if (!isUsed)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on,
                              color: Colors.white, size: 8),
                          const SizedBox(width: 2),
                          Text(
                            '$cost',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isUsed
                    ? Colors.greenAccent.withOpacity(0.8)
                    : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question q) {
    return FadeTransition(
      opacity: _animationController,
      child: GlassContainer(
        opacity: 0.05,
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          q.question,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              height: 1.4),
        ),
      ),
    );
  }

  Widget _buildOptionsList(Question q) {
    return Column(
      children: List.generate(q.options.length, (index) {
        final isSelected = _selectedIndex == index;
        final isEliminated = _eliminatedOptions.contains(index);
        final isCorrectOption = index == q.correctIndex;

        Color borderColor = isSelected
            ? const Color(0xFF6366F1).withOpacity(0.8)
            : Colors.white.withOpacity(0.08);
        Color bgColor = isSelected
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.04);
        Color iconColor = const Color(0xFF6366F1);
        Color optionBoxColor = isSelected ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.1);
        Color textColor = isSelected ? Colors.white : Colors.white70;
        IconData? displayIcon;

        if (_isShowingAnswer) {
          if (isCorrectOption) {
            bgColor = Colors.greenAccent.withOpacity(0.25);
            borderColor = Colors.greenAccent;
            iconColor = Colors.greenAccent;
            optionBoxColor = Colors.greenAccent;
            textColor = Colors.white;
            displayIcon = Icons.check_circle_rounded;
          } else if (isSelected && !isCorrectOption) {
            bgColor = Colors.redAccent.withOpacity(0.25);
            borderColor = Colors.redAccent;
            iconColor = Colors.redAccent;
            optionBoxColor = Colors.redAccent;
            textColor = Colors.white;
            displayIcon = Icons.cancel_rounded;
          } else if (isSelected) {
            displayIcon = Icons.check_circle_rounded;
          }
        } else if (isSelected) {
          displayIcon = Icons.check_circle_rounded;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FadeTransition(
            opacity: _optionAnimations[index],
            child: ScaleTransition(
              scale: _optionAnimations[index],
              child: GestureDetector(
                onTap: () {
                  if (!_isShowingAnswer) _onOptionSelected(index);
                },
                child: Opacity(
                  opacity: isEliminated ? 0.3 : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected || (_isShowingAnswer && isCorrectOption) ? 2 : 1.5,
                      ),
                      boxShadow: isSelected || (_isShowingAnswer && isCorrectOption)
                          ? [
                              BoxShadow(
                                  color: borderColor.withOpacity(0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2)
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: optionBoxColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                  color: (isSelected || (_isShowingAnswer && (isCorrectOption || isSelected)))
                                      ? Colors.white
                                      : Colors.white60,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            q.options[index],
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: (isSelected || (_isShowingAnswer && isCorrectOption))
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              decoration: isEliminated
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (displayIcon != null)
                          Icon(displayIcon, color: iconColor, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (_selectedIndex != null)
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _selectedIndex != null ? _goNext : null,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero, // Important for Ink or Container children
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: _selectedIndex != null
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: _selectedIndex == null
                  ? Colors.white.withOpacity(0.05)
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _currentIndex == widget.questions.length - 1
                    ? 'quiz.finish_test'.tr()
                    : 'quiz.next_question'.tr(),
                style: TextStyle(
                  color: _selectedIndex != null ? Colors.white : Colors.white24,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated "..." thinking indicator for bot
class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            final opacity = (math.sin(t * math.pi)).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
