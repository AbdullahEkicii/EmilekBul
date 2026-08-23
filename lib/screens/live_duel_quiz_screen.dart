import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/duel_room_model.dart';
import '../models/question.dart';
import '../services/duel_service.dart';
import '../services/sound_service.dart';
import '../services/user_service.dart';
import '../services/token_service.dart';
import '../services/bot_quiz_simulator.dart';
import '../services/bot_room_service.dart';
import '../utils/app_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/my_native_ad.dart';
import 'live_duel_result_screen.dart';

class LiveDuelQuizScreen extends StatefulWidget {
  final DuelRoom room;
  final bool isHost;

  const LiveDuelQuizScreen({
    super.key,
    required this.room,
    required this.isHost,
  });

  @override
  State<LiveDuelQuizScreen> createState() => _LiveDuelQuizScreenState();
}

class _LiveDuelQuizScreenState extends State<LiveDuelQuizScreen>
  with TickerProviderStateMixin {
  late StreamSubscription<DuelRoom?> _roomSubscription;
  DuelRoom? _liveRoom;

  int _currentIndex = 0;
  int? _selectedIndex;
  late List<int?> _userAnswers;
  int _localScore = 0;
  int _combo = 0;
  bool _isShowingAnswer = false;
  bool _localFinished = false;
  bool _isTransitioning = false;
  bool _showFeedbackBadge = false;
  bool _lastAnswerCorrect = false;

  // Joker States
  final List<int> _eliminatedOptions = [];
  bool _isDoubleAnswerActive = false;
  bool _isDoubleAnswerUsedInCurrentQuestion = false;
  bool _isFiftyFiftyUsedInCurrentQuestion = false;
  int _userTokens = 0;

  // Combo Popup
  late AnimationController _comboController;
  late Animation<double> _comboScaleAnimation;
  late Animation<double> _comboOpacityAnimation;
  bool _showComboPopup = false;
  int _comboTriggerValue = 0;

  // Feedback Popup
  late AnimationController _feedbackController;
  late Animation<double> _feedbackScaleAnimation;

  BotQuizSimulator? _botSimulator;

  late Stopwatch _stopwatch;
  late ValueNotifier<int> _remainingSeconds;
  Timer? _questionTimer;
  static const int _questionDuration = 35;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _liveRoom = widget.room;
    _userAnswers = List<int?>.filled(widget.room.questions.length, null);
    _stopwatch = Stopwatch()..start();
    _remainingSeconds = ValueNotifier<int>(_questionDuration);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

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

    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _feedbackScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.25).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 40),
    ]).animate(_feedbackController);

    _loadUserTokens();
    _startQuestionTimer();
    _listenToRoom();

    // Eğer rakip bir botsa maç simülatörünü başlat
    final opponent = widget.isHost ? widget.room.guest : widget.room.host;
    if (opponent != null && BotRoomService.isBot(opponent.uid)) {
      _botSimulator = BotQuizSimulator(
        roomCode: widget.room.roomCode,
        room: widget.room,
        isHostBot: !widget.isHost,
      );
      _botSimulator!.start();
    }
  }

  Future<void> _loadUserTokens() async {
    try {
      final tokens = await TokenService.getTokenAmount();
      if (mounted) {
        setState(() => _userTokens = tokens);
      }
    } catch (_) {}
  }

  void _listenToRoom() {
    _roomSubscription = DuelService.streamRoom(widget.room.roomCode).listen((room) {
      if (!mounted || room == null) return;

      setState(() {
        _liveRoom = room;
      });

      // Her iki oyuncu da bittiyse veya soru sayısına ulaştıysa sonuç ekranına geç
      final totalQ = room.questions.length;
      final hostFinished = room.host.finished || (totalQ > 0 && room.host.progress >= totalQ) || (widget.isHost && _localFinished);
      final guestFinished = (room.guest?.finished ?? false) || (totalQ > 0 && (room.guest?.progress ?? 0) >= totalQ) || (!widget.isHost && _localFinished);

      if ((hostFinished && guestFinished) || room.status == 'finished') {
        _navigateToResults();
      }
    });
  }

  bool _hasNavigatedToResults = false;

  void _navigateToResults() {
    if (_hasNavigatedToResults) return;
    _hasNavigatedToResults = true;
    _questionTimer?.cancel();
    _roomSubscription.cancel();
    _botSimulator?.cancel();

    // Trigger resolution in background
    DuelService.resolveDuelResult(widget.room.roomCode);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LiveDuelResultScreen(
            roomCode: widget.room.roomCode,
            isHost: widget.isHost,
            initialRoom: _liveRoom ?? widget.room,
          ),
        ),
        (route) => route.isFirst,
      );
    });
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _remainingSeconds.value = _questionDuration;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds.value > 0) {
        _remainingSeconds.value--;
      } else {
        timer.cancel();
        _handleAnswer(-1); // Timeout
      }
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    final currentQuestion = widget.room.questions[_currentIndex];
    final wrongOptions = <int>[];

    for (int i = 0; i < currentQuestion.options.length; i++) {
      if (i != currentQuestion.correctIndex && !_eliminatedOptions.contains(i)) {
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

    _handleAnswer(widget.room.questions[_currentIndex].correctIndex);

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

  void _handleAnswer(int selectedIndex) {
    if (_isShowingAnswer || _localFinished || _isTransitioning) return;

    final questions = widget.room.questions;
    if (_currentIndex >= questions.length) return;

    final currentQ = questions[_currentIndex];

    // Double answer active check
    if (_isDoubleAnswerActive && selectedIndex != -1 && selectedIndex != currentQ.correctIndex) {
      setState(() {
        _eliminatedOptions.add(selectedIndex);
        _isDoubleAnswerActive = false;
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

    _questionTimer?.cancel();
    final bool isCorrect = selectedIndex == currentQ.correctIndex;

    setState(() {
      _selectedIndex = selectedIndex;
      _isShowingAnswer = true;
      _userAnswers[_currentIndex] = selectedIndex;
      _lastAnswerCorrect = isCorrect;
      _showFeedbackBadge = true;

      if (isCorrect) {
        _combo++;
        if (_combo >= 3) {
          _comboTriggerValue = _combo;
          _showComboPopup = true;
          _comboController.forward(from: 0).then((_) {
            if (mounted) setState(() => _showComboPopup = false);
          });
        }
        final remaining = _remainingSeconds.value.clamp(0, _questionDuration);
        final speedBonus = remaining * 4;
        final comboBonus = (_combo > 1 ? (_combo * 10) : 0);
        _localScore += 50 + speedBonus + comboBonus;
        SoundService.playCorrect();
      } else {
        _combo = 0;
        SoundService.playWrong();
      }
    });

    HapticFeedback.mediumImpact();
    _feedbackController.forward(from: 0.0);

    // Update progress in Firestore
    final nextProgress = _currentIndex + 1;
    final isLastQuestion = nextProgress >= questions.length;

    DuelService.updatePlayerProgress(
      roomCode: widget.room.roomCode,
      isHost: widget.isHost,
      progress: nextProgress,
      score: _localScore,
      finished: isLastQuestion,
      finishTime: isLastQuestion ? _stopwatch.elapsedMilliseconds : 0,
      userAnswers: _userAnswers,
    );

    // Soru doğru/yanlış geri bildirimini kullanıcının net görmesi için 1400ms bekle
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;

      if (isLastQuestion) {
        setState(() {
          _showFeedbackBadge = false;
          _localFinished = true;
        });

        // Rakip zaten bitirdiyse veya tüm soruları tamamladıysa hemen sonuç ekranına geç
        final opponent = widget.isHost ? _liveRoom?.guest : _liveRoom?.host;
        final totalQ = widget.room.questions.length;
        final isOpponentDone = (opponent?.finished == true) || (totalQ > 0 && (opponent?.progress ?? 0) >= totalQ);
        if (isOpponentDone) {
          _navigateToResults();
        }
      } else {
        // Step 1: Diğer soru hazırlanıyor geçişini başlat
        setState(() {
          _showFeedbackBadge = false;
          _isTransitioning = true;
          _currentIndex++;
          _selectedIndex = null;
          _isShowingAnswer = false;
          _eliminatedOptions.clear();
          _isDoubleAnswerActive = false;
          _isDoubleAnswerUsedInCurrentQuestion = false;
          _isFiftyFiftyUsedInCurrentQuestion = false;
        });

        // Step 2: 1300ms'lik rahat geçiş beklemesi
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (!mounted) return;

          setState(() {
            _isTransitioning = false;
          });

          _fadeController.forward(from: 0.0);
          _startQuestionTimer();
        });
      }
    });
  }

  @override
  void dispose() {
    _botSimulator?.cancel();
    _questionTimer?.cancel();
    _roomSubscription.cancel();
    _fadeController.dispose();
    _comboController.dispose();
    _feedbackController.dispose();
    _remainingSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _liveRoom ?? widget.room;
    final questions = room.questions;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopRaceTrack(room),
                if (!_localFinished && _currentIndex < questions.length) ...[
                  Expanded(
                    child: Stack(
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 10),
                                _buildQuestionCard(questions[_currentIndex]),
                                const SizedBox(height: 14),
                                _buildQuickJokersRow(),
                                const SizedBox(height: 14),
                                _buildOptionsList(questions[_currentIndex]),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        if (_showComboPopup) _buildComboPopup(),
                        if (_showFeedbackBadge) _buildFeedbackBanner(),
                        if (_isTransitioning) _buildTransitionOverlay(),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: MyNativeAd(
                      height: 65,
                      factoryId: 'adFactorySmall',
                    ),
                  ),
                ] else ...[
                  Expanded(child: _buildWaitingOpponentView(room)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    final isCorrect = _lastAnswerCorrect;
    final Color bannerColor = isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final String text = isCorrect ? 'duel.feedback_correct'.tr() : 'duel.feedback_wrong'.tr();
    final IconData icon = isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Center(
      child: ScaleTransition(
        scale: _feedbackScaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: bannerColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: bannerColor, size: 32),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  color: bannerColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransitionOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: const Color(0xFF0F172A).withValues(alpha: 0.8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Color(0xFF818CF8),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'duel.next_question_preparing'.tr(args: [(_currentIndex + 1).toString()]),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'quiz.preparing_${((_currentIndex) % 5) + 1}'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
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

  Widget _buildTopRaceTrack(DuelRoom room) {
    final myPlayer = widget.isHost ? room.host : (room.guest ?? room.host);
    final opponentPlayer = widget.isHost ? (room.guest ?? room.host) : room.host;
    final totalQ = room.questions.length;

    // Calculate correct answers for me (using LOCAL state _userAnswers prioritized over Firestore stream)
    int myCorrect = 0;
    for (int i = 0; i < totalQ; i++) {
      final ans = (i < _userAnswers.length && _userAnswers[i] != null)
          ? _userAnswers[i]
          : (i < myPlayer.userAnswers.length ? myPlayer.userAnswers[i] : null);
      if (ans != null && ans == room.questions[i].correctIndex) {
        myCorrect++;
      }
    }

    // Calculate correct answers for opponent (from remote stream)
    int oppCorrect = 0;
    for (int i = 0; i < opponentPlayer.userAnswers.length && i < totalQ; i++) {
      if (opponentPlayer.userAnswers[i] == room.questions[i].correctIndex) {
        oppCorrect++;
      }
    }

    final int myScore = _localScore;
    final int oppScore = opponentPlayer.score;

    String statusText;
    Color statusColor;
    if (myCorrect > oppCorrect) {
      statusText = 'duel.status_player_leading'.tr();
      statusColor = const Color(0xFF10B981);
    } else if (oppCorrect > myCorrect) {
      statusText = 'duel.status_bot_leading'.tr();
      statusColor = const Color(0xFFEF4444);
    } else {
      if (myScore > oppScore) {
        statusText = 'duel.status_player_leading'.tr();
        statusColor = const Color(0xFF10B981);
      } else if (oppScore > myScore) {
        statusText = 'duel.status_bot_leading'.tr();
        statusColor = const Color(0xFFEF4444);
      } else {
        statusText = 'duel.status_equal'.tr();
        statusColor = const Color(0xFFFFB020);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        children: [
          // Status pill & Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _remainingSeconds,
                builder: (context, seconds, _) {
                  final isLow = seconds <= 7;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLow
                          ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                          : const Color(0xFFFFD56B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLow ? const Color(0xFFEF4444) : const Color(0xFFFFD56B).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          color: isLow ? const Color(0xFFEF4444) : const Color(0xFFFFD56B),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${seconds}sn',
                          style: TextStyle(
                            color: isLow ? const Color(0xFFEF4444) : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Player 1 (You) Row
          _buildPlayerTrackRow(
            player: myPlayer,
            isMe: true,
            totalQ: totalQ,
            correctCount: myCorrect,
            displayScore: myScore,
            room: room,
          ),
          const SizedBox(height: 8),

          // Player 2 (Opponent) Row
          _buildPlayerTrackRow(
            player: opponentPlayer,
            isMe: false,
            totalQ: totalQ,
            correctCount: oppCorrect,
            displayScore: oppScore,
            room: room,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTrackRow({
    required DuelPlayer player,
    required bool isMe,
    required int totalQ,
    required int correctCount,
    required int displayScore,
    required DuelRoom room,
  }) {
    final hasAvatar = UserService.hasAvatar(player.avatarIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;
        final profileWidth = isSmallScreen ? 76.0 : 88.0;

        return Row(
          children: [
            // Avatar + Name + Correct Count
            SizedBox(
              width: profileWidth,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isSmallScreen ? 11 : 13,
                    backgroundColor: isMe ? const Color(0xFF10B981) : const Color(0xFFFF5252),
                    backgroundImage: hasAvatar
                        ? ResizeImage(
                            AssetImage(UserService.getAvatarPath(player.avatarIndex)),
                            width: 48,
                            height: 48,
                          )
                        : null,
                    child: hasAvatar ? null : const Icon(Icons.person_rounded, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isMe ? 'duel.you'.tr() : AppUtils.localizeUsername(player.username),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: isSmallScreen ? 10 : 11,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$correctCount D • ${displayScore}p',
                            style: TextStyle(
                              color: isMe ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 8.5 : 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Segmented Question Steps
            Expanded(
              child: Row(
                children: List.generate(totalQ, (qIndex) {
                  final localAnswer = (isMe && qIndex < _userAnswers.length) ? _userAnswers[qIndex] : null;
                  final remoteAnswer = (qIndex < player.userAnswers.length) ? player.userAnswers[qIndex] : null;
                  final answer = isMe ? (localAnswer ?? remoteAnswer) : remoteAnswer;
                  final isAnswered = answer != null;
                  final bool? isCorrect = isAnswered
                      ? (answer == room.questions[qIndex].correctIndex)
                      : null;
                  final isCurrent = isMe
                      ? (_currentIndex == qIndex && !_localFinished)
                      : (player.progress == qIndex && !player.finished);

                  Color bgColor;
                  Color borderColor;
                  Widget child;

                  if (isAnswered) {
                    if (isCorrect == true) {
                      bgColor = const Color(0xFF10B981);
                      borderColor = const Color(0xFF34D399);
                      child = const Icon(Icons.check_rounded, size: 13, color: Colors.white);
                    } else {
                      bgColor = const Color(0xFFEF4444);
                      borderColor = const Color(0xFFF87171);
                      child = const Icon(Icons.close_rounded, size: 13, color: Colors.white);
                    }
                  } else if (isCurrent) {
                    bgColor = isMe
                        ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                        : const Color(0xFFFF9F43).withValues(alpha: 0.35);
                    borderColor = isMe ? const Color(0xFF818CF8) : const Color(0xFFFFB020);
                    child = Text(
                      '${qIndex + 1}',
                      style: TextStyle(
                        color: isMe ? const Color(0xFFA5B4FC) : const Color(0xFFFFD56B),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    );
                  } else {
                    bgColor = Colors.white.withValues(alpha: 0.05);
                    borderColor = Colors.white.withValues(alpha: 0.1);
                    child = Text(
                      '${qIndex + 1}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    );
                  }

                  return Expanded(
                    child: Container(
                      height: isSmallScreen ? 20 : 22,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 1),
                      ),
                      child: Center(child: child),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
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
    final bool canTap = isEnabled && !isUsed && !_isShowingAnswer && !_localFinished;
    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: Opacity(
        opacity: canTap ? 1.0 : (isUsed ? 0.5 : 0.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUsed ? Colors.grey.withValues(alpha: 0.3) : color.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: canTap
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    isUsed ? Icons.check_rounded : icon,
                    color: isUsed ? Colors.greenAccent : color,
                    size: 22,
                  ),
                ),
                if (!isUsed)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.white, size: 8),
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
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isUsed ? Colors.greenAccent.withValues(alpha: 0.8) : Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboPopup() {
    return Center(
      child: FadeTransition(
        opacity: _comboOpacityAnimation,
        child: ScaleTransition(
          scale: _comboScaleAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9F43), Color(0xFFFF5252)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 6),
                    Text(
                      '${_comboTriggerValue}X COMBO!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question q) {
    final localizedQuestion = q.getLocalizedQuestion(context.locale.languageCode);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F43).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'quiz.question_progress'.tr(args: [
                    '${_currentIndex + 1}',
                    '${widget.room.questions.length}',
                  ]),
                  style: const TextStyle(
                    color: Color(0xFFFFD56B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),

              // Countdown Timer
              ValueListenableBuilder<int>(
                valueListenable: _remainingSeconds,
                builder: (context, seconds, child) {
                  final isLow = seconds <= 7;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLow
                          ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLow ? Colors.redAccent : Colors.amber.withValues(alpha: 0.6),
                        width: isLow ? 1.5 : 1.0,
                      ),
                      boxShadow: isLow
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alarm_on_rounded,
                          color: isLow ? Colors.white : Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${seconds}s',
                          style: TextStyle(
                            color: isLow ? Colors.white : const Color(0xFFFFD56B),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            localizedQuestion,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(Question q) {
    final localizedOptions = q.getLocalizedOptions(context.locale.languageCode);

    return Column(
      children: List.generate(localizedOptions.length, (index) {
        final optionText = localizedOptions[index];
        final bool isSelected = _selectedIndex == index;
        final bool isCorrect = index == q.correctIndex;
        final bool isEliminated = _eliminatedOptions.contains(index);

        Color borderColor = Colors.white12;
        Color backgroundColor = Colors.white.withValues(alpha: 0.05);

        if (_isShowingAnswer) {
          if (isCorrect) {
            borderColor = const Color(0xFF10B981);
            backgroundColor = const Color(0xFF10B981).withValues(alpha: 0.25);
          } else if (isSelected) {
            borderColor = const Color(0xFFEF4444);
            backgroundColor = const Color(0xFFEF4444).withValues(alpha: 0.25);
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Opacity(
            opacity: isEliminated ? 0.25 : 1.0,
            child: InkWell(
              onTap: (_isShowingAnswer || isEliminated) ? null : () => _handleAnswer(index),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: isSelected || isCorrect ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        String.fromCharCode(65 + index),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        optionText,
                        style: TextStyle(
                          color: isEliminated ? Colors.white38 : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          decoration: isEliminated ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (_isShowingAnswer && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                    else if (_isShowingAnswer && isSelected)
                      const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWaitingOpponentView(DuelRoom room) {
    final opponent = widget.isHost ? room.guest : room.host;
    final opponentName = AppUtils.localizeUsername(opponent?.username);

    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(28),
        borderRadius: 24,
        opacity: 0.12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 64),
            const SizedBox(height: 16),
            Text(
              'duel.player_finished_first'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              '${'duel.your_score'.tr()}: $_localScore ${'welcome_screen.points'.tr()}',
              style: const TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFFFF9F43)),
            const SizedBox(height: 16),
            Text(
              'duel.waiting_opponent_finish'.tr(args: [opponentName]),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
