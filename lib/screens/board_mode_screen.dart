import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/token_economy.dart';
import '../services/token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import '../services/ai_api_service.dart';
import '../services/board_mode_service.dart';
import '../services/database_helper.dart';
import '../services/haptic_service.dart';
import '../services/interstitial_ad_manager.dart';
import '../services/offline_quiz_service.dart';
import '../services/rewarded_boost.dart';
import '../services/sound_service.dart';
import '../utils/app_motion.dart';
import '../widgets/glass_container.dart';
import '../widgets/my_native_ad.dart';
import 'speed_round_screen.dart';

enum _Phase { idle, loading, board, finished }

/// Çarpanlı tahta: 3x3 gizli çarpanlı kareler. Her kare seçildiğinde çarpanı açılır,
/// bir soru sorulur ve doğru cevap `100 * çarpan` puan verir. 9 kare bitince oyun sona erer.
/// Tamamen yerel çalışır (Firestore yok).
class BoardModeScreen extends StatefulWidget {
  const BoardModeScreen({super.key});

  static const String bestKey = 'board_mode_best';
  static const List<String> _difficulties = ['Kolay', 'Orta', 'Zor', 'Imkansız'];

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BoardModeScreen()),
    );
  }

  @override
  State<BoardModeScreen> createState() => _BoardModeScreenState();
}

class _BoardModeScreenState extends State<BoardModeScreen> {
  _Phase _phase = _Phase.idle;
  List<int> _board = const [];
  List<Question> _questions = const [];
  int _qCursor = 0; // Şu ana kadar sorulan soru sayısı (her cevapta artar)
  int? _activeTile; // Çarpanı açılmış ve cevabı bekleyen kare
  final Set<int> _revealed = {}; // Açılmış kareler
  final Map<int, int> _earned = {}; // Cevaplanmış (kilitli) kareler -> kazanılan puan
  int? _selected; // Seçilen şık (geri bildirim süresince kilitli)
  int _score = 0;
  int _best = 0;
  bool _newBest = false;
  Timer? _nextTimer;
  final RewardedBoost _rewardedBoost = RewardedBoost();
  int _lastPayout = 0;
  bool _doubleRewardClaimed = false;
  bool _doubleRewardLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _rewardedBoost.load();
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _best = prefs.getInt(BoardModeScreen.bestKey) ?? 0);
    } catch (e) {
      debugPrint('Çarpanlı tahta en iyi skor okuma hatası: $e');
    }
  }

  /// Yerel önbellekten kategori soruları (speed round ile aynı kaynak); yetmezse yerleşik sorular.
  Future<List<Question>> _loadQuestions(String lang) async {
    final pool = <Question>[];
    final seen = <String>{};
    final category = SpeedRoundScreen.weeklyCategory().name;
    try {
      for (final diff in BoardModeScreen._difficulties) {
        final rows = await DatabaseHelper.instance.getRecycledCachedQuestions(
          category: category,
          difficulty: diff,
          languageCode: lang,
          count: 40,
        );
        for (final q in rows) {
          if (AiApiService.isCompactQuestion(q) && seen.add(q.question)) pool.add(q);
        }
      }
    } catch (e) {
      debugPrint('Çarpanlı tahta önbellek okuma hatası: $e');
    }
    if (pool.length < BoardModeService.tileCount) {
      for (final q in OfflineQuizService.getFallbackQuestions(languageCode: lang, count: 30)) {
        if (seen.add(q.question)) pool.add(q);
      }
    }
    pool.shuffle(Random());
    return pool.take(BoardModeService.tileCount).toList();
  }

  Future<void> _start() async {
    if (_phase == _Phase.loading) return;
    final lang = context.locale.languageCode;
    HapticService.selection();
    setState(() => _phase = _Phase.loading);

    final qs = await _loadQuestions(lang);
    if (!mounted) return;
    if (qs.length < BoardModeService.tileCount) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    final paid = await TokenService.spendTokens(TokenEconomy.boardEntryCost, reason: 'board_entry');
    if (!paid) {
      setState(() => _phase = _Phase.idle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('quiz.not_enough_tokens'.tr(args: [TokenEconomy.boardEntryCost.toString()])),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }
    setState(() {
      _questions = qs;
      _board = BoardModeService.buildBoard(random: Random());
      _revealed.clear();
      _earned.clear();
      _activeTile = null;
      _selected = null;
      _qCursor = 0;
      _score = 0;
      _newBest = false;
      _lastPayout = 0;
      _doubleRewardClaimed = false;
      _doubleRewardLoading = false;
      _phase = _Phase.board;
    });
  }

  void _onTileTap(int i) {
    if (_phase != _Phase.board || _activeTile != null || _revealed.contains(i)) return;
    HapticService.selection();
    setState(() {
      _revealed.add(i);
      _activeTile = i;
      _selected = null;
    });
  }

  void _answer(int optionIndex) {
    final tile = _activeTile;
    if (tile == null || _selected != null) return;
    final q = _questions[_qCursor];
    final correct = optionIndex == q.correctIndex;
    final points = BoardModeService.scoreQuestion(
      correct: correct,
      multiplier: _board[tile],
    );
    if (correct) {
      HapticService.correct();
      SoundService.playCorrect();
    } else {
      HapticService.wrong();
      SoundService.playWrong();
    }
    setState(() {
      _selected = optionIndex;
      _earned[tile] = points;
      _score += points;
    });
    // Kısa geri bildirimden sonra tahtaya dön (ya da oyunu bitir)
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 900), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (BoardModeService.isBoardComplete(_earned.length)) {
      _finish();
      return;
    }
    setState(() {
      _activeTile = null;
      _selected = null;
      _qCursor++;
    });
  }

  Future<void> _finish() async {
    _nextTimer?.cancel();
    final score = _score;
    final payout = score ~/ TokenEconomy.boardPointsPerToken;
    setState(() {
      _phase = _Phase.finished;
      _activeTile = null;
      _selected = null;
      _lastPayout = payout;
    });
    HapticService.medium();

    if (payout > 0) {
      _rewardedBoost.load();
      await TokenService.addTokens(payout, source: 'board_mode');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('token.reward_flat'.tr(args: ['$payout'])),
          backgroundColor: Colors.indigo,
        ));
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final prev = prefs.getInt(BoardModeScreen.bestKey) ?? 0;
      final best = BoardModeService.bestScore(prev, score);
      if (best > prev) await prefs.setInt(BoardModeScreen.bestKey, best);
      if (!mounted) return;
      setState(() {
        _best = best;
        _newBest = score > prev;
      });
    } catch (e) {
      debugPrint('Çarpanlı tahta en iyi skor kaydetme hatası: $e');
    }

    unawaited(InterstitialAdManager.onTestFinished(source: 'board_mode'));
  }

  Future<void> _claimDoubleReward(int payout) async {
    if (_doubleRewardClaimed || _doubleRewardLoading || payout <= 0) return;
    setState(() => _doubleRewardLoading = true);
    final claimed = await claimDoubleRewardWithAd(
      context,
      boost: _rewardedBoost,
      payout: payout,
      tokenSource: 'board_double_reward',
    );
    if (!mounted) return;
    setState(() {
      _doubleRewardLoading = false;
      if (claimed) _doubleRewardClaimed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBody(context.locale.languageCode),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: MyNativeAd(height: 65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'board_mode.title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBody(String lang) {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.loading:
        return _buildIntro();
      case _Phase.board:
        return _buildBoard(lang);
      case _Phase.finished:
        return _buildFinished();
    }
  }

  Widget _buildIntro() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_3x3_rounded, size: 72, color: Color(0xFF00D2D3)),
            const SizedBox(height: 16),
            Text(
              'board_mode.subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
            ),
            const SizedBox(height: 16),
            Text(
              '${'board_mode.best'.tr()}: $_best',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 28),
            if (_phase == _Phase.loading)
              const CircularProgressIndicator(color: Colors.white)
            else
              _buildPrimaryButton('board_mode.start'.tr(), _start),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(String lang) {
    final tile = _activeTile;
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'board_mode.score'.tr(),
                  '$_score',
                  const Color(0xFF96CEB4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'board_mode.best'.tr(),
                  '$_best',
                  const Color(0xFF45B7D1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: BoardModeService.tileCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (_, i) => _buildTile(i),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (tile == null)
            Text(
              'board_mode.reveal'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
            )
          else
            _buildQuestion(lang, tile),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTile(int i) {
    final revealed = _revealed.contains(i);
    final isActive = _activeTile == i;
    final earned = _earned[i];
    return GestureDetector(
      onTap: () => _onTileTap(i),
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context, const Duration(milliseconds: 350)),
        transitionBuilder: (child, anim) {
          // Yarım dönüşlü çevirme: kapalı yüz -> açık yüz
          final angle = Tween<double>(begin: pi / 2, end: 0).animate(anim);
          return AnimatedBuilder(
            animation: angle,
            child: child,
            builder: (context, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle.value),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey('tile_$i-$revealed'),
          child: revealed
              ? _faceRevealed(_board[i], isActive: isActive, earned: earned)
              : _faceBack(),
        ),
      ),
    );
  }

  Widget _faceBack() {
    return GlassContainer(
      opacity: 0.1,
      padding: EdgeInsets.zero,
      child: const Center(
        child: Icon(Icons.help_outline_rounded, color: Colors.white54, size: 32),
      ),
    );
  }

  Widget _faceRevealed(int multiplier, {required bool isActive, int? earned}) {
    final color = _multiplierColor(multiplier);
    final locked = earned != null;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: locked ? 0.15 : 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.white : color,
          width: isActive ? 2.5 : 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${multiplier}x',
              style: TextStyle(
                color: locked ? color.withValues(alpha: 0.6) : Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (locked)
              Text(
                '+$earned',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(String lang, int tile) {
    final q = _questions[_qCursor];
    final options = q.getLocalizedOptions(lang);
    final multiplier = _board[tile];
    return Column(
      children: [
        Text(
          'board_mode.multiplier_label'.tr(args: ['${multiplier}x']),
          style: TextStyle(
            color: _multiplierColor(multiplier),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        GlassContainer(
          opacity: 0.1,
          padding: const EdgeInsets.all(20),
          child: Text(
            q.getLocalizedQuestion(lang),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildOption(options[i], i, q.correctIndex),
          ),
      ],
    );
  }

  Widget _buildOption(String text, int i, int correctIndex) {
    final answered = _selected != null;
    Color bg = Colors.white.withValues(alpha: 0.08);
    Color border = Colors.white.withValues(alpha: 0.2);
    if (answered && i == correctIndex) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.35);
      border = const Color(0xFF10B981);
    } else if (answered && i == _selected) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.35);
      border = const Color(0xFFEF4444);
    }
    return GestureDetector(
      onTap: () => _answer(i),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, const Duration(milliseconds: 200)),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildFinished() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'board_mode.done'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            GlassContainer(
              opacity: 0.1,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'board_mode.score'.tr(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_score',
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'board_mode.best'.tr()}: $_best',
                    style: const TextStyle(color: Color(0xFFFECA57), fontWeight: FontWeight.w700),
                  ),
                  if (_newBest) ...[
                    const SizedBox(height: 8),
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD56B), size: 22),
                  ],
                ],
              ),
            ),
            if (_lastPayout > 0) ...[
              const SizedBox(height: 16),
              DoubleRewardCard(
                payout: _lastPayout,
                claimed: _doubleRewardClaimed,
                loading: _doubleRewardLoading,
                onTap: () => _claimDoubleReward(_lastPayout),
              ),
            ],
            const SizedBox(height: 24),
            _buildPrimaryButton('board_mode.play_again'.tr(), _start),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF00D2D3)]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }

  static Color _multiplierColor(int m) {
    if (m >= 3) return const Color(0xFFFFD56B);
    if (m == 2) return const Color(0xFF00D2D3);
    return const Color(0xFF94A3B8);
  }
}
