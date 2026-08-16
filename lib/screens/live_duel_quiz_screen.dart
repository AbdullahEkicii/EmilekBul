import 'dart:async';
import 'package:flutter/material.dart';
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

  BotQuizSimulator? _botSimulator;

  late Stopwatch _stopwatch;
  late ValueNotifier<int> _remainingSeconds;
  Timer? _questionTimer;
  static const int _questionDuration = 25;

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
      final hostFinished = room.host.finished || (totalQ > 0 && room.host.progress >= totalQ);
      final guestFinished = (room.guest?.finished ?? false) || (totalQ > 0 && (room.guest?.progress ?? 0) >= totalQ);

      if ((hostFinished && guestFinished) || room.status == 'finished') {
        _navigateToResults();
      }
    });
  }

  void _navigateToResults() {
    _questionTimer?.cancel();
    _roomSubscription.cancel();

    // Trigger resolution in background
    DuelService.resolveDuelResult(widget.room.roomCode);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LiveDuelResultScreen(
          roomCode: widget.room.roomCode,
          isHost: widget.isHost,
        ),
      ),
    );
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
    if (_isShowingAnswer || _localFinished) return;

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

      if (isCorrect) {
        _combo++;
        if (_combo >= 3) {
          _comboTriggerValue = _combo;
          _showComboPopup = true;
          _comboController.forward(from: 0).then((_) {
            if (mounted) setState(() => _showComboPopup = false);
          });
        }
        _localScore += 10 + (_combo > 1 ? (_combo * 2) : 0);
        SoundService.playCorrect();
      } else {
        _combo = 0;
        SoundService.playWrong();
      }
    });

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

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      if (isLastQuestion) {
        setState(() {
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
        setState(() {
          _currentIndex++;
          _selectedIndex = null;
          _isShowingAnswer = false;
          _eliminatedOptions.clear();
          _isDoubleAnswerActive = false;
          _isDoubleAnswerUsedInCurrentQuestion = false;
          _isFiftyFiftyUsedInCurrentQuestion = false;
        });
        _fadeController.forward(from: 0.0);
        _startQuestionTimer();
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
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                        if (_showComboPopup) _buildComboPopup(),
                      ],
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

  Widget _buildTopRaceTrack(DuelRoom room) {
    final myPlayer = widget.isHost ? room.host : (room.guest ?? room.host);
    final opponentPlayer = widget.isHost ? (room.guest ?? room.host) : room.host;
    final totalQ = room.questions.length;

    final myProgress = (myPlayer.progress / (totalQ > 0 ? totalQ : 1)).clamp(0.0, 1.0);
    final oppProgress = (opponentPlayer.progress / (totalQ > 0 ? totalQ : 1)).clamp(0.0, 1.0);

    String statusText = 'duel.status_equal'.tr();
    Color statusColor = Colors.amber;
    if (myPlayer.score > opponentPlayer.score) {
      statusText = 'duel.status_player_leading'.tr();
      statusColor = const Color(0xFF10B981);
    } else if (opponentPlayer.score > myPlayer.score) {
      statusText = 'duel.status_bot_leading'.tr();
      statusColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),

          // Race Track
          Row(
            children: [
              // You
              _buildRaceUserPill(myPlayer, isMe: true),
              const SizedBox(width: 8),

              // Track Bars
              Expanded(
                child: Column(
                  children: [
                    // My Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: myProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Opponent Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: oppProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Opponent
              _buildRaceUserPill(opponentPlayer, isMe: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRaceUserPill(DuelPlayer player, {required bool isMe}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (context) {
            final hasAvatar = UserService.hasAvatar(player.avatarIndex);
            return CircleAvatar(
              radius: 14,
              backgroundColor: isMe ? const Color(0xFF10B981) : const Color(0xFFFF5252),
              backgroundImage: hasAvatar
                  ? ResizeImage(
                      AssetImage(UserService.getAvatarPath(player.avatarIndex)),
                      width: 56,
                      height: 56,
                    )
                  : null,
              child: hasAvatar
                  ? null
                  : const Icon(Icons.person_rounded, size: 14, color: Colors.white),
            );
          },
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              isMe ? 'duel.you'.tr() : AppUtils.localizeUsername(player.username),
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            ),
            Text(
              '${player.score} ${'welcome_screen.points'.tr()}',
              style: TextStyle(
                color: isMe ? const Color(0xFF34D399) : const Color(0xFFF87171),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
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
                  final isLow = seconds <= 5;
                  return Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: isLow ? Colors.redAccent : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$seconds',
                        style: TextStyle(
                          color: isLow ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
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
