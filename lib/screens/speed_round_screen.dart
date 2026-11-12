import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/token_economy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_categories.dart';
import '../models/category_model.dart';
import '../models/question.dart';
import '../services/ai_api_service.dart';
import '../services/database_helper.dart';
import '../services/haptic_service.dart';
import '../services/league_service.dart';
import '../services/offline_quiz_service.dart';
import '../services/sound_service.dart';
import '../services/token_service.dart';
import '../utils/app_motion.dart';
import '../widgets/glass_container.dart';

enum _Phase { idle, loading, running, finished }

/// Hız turu: 60 saniyede mümkün olduğunca çok soruyu doğru bilmeye çalış.
/// Kategori her hafta deterministik olarak seçilir (herkes aynı kategoriyi görür).
class SpeedRoundScreen extends StatefulWidget {
  /// [category] verilmezse haftalık kategori kullanılır.
  /// [tournamentMode] true iken haftalık en iyi skor/ödül yazılmaz; tur bitince
  /// ekran skoru `Navigator.pop(score)` ile döndürür (turnuva skoru çağıran tarafça gönderilir).
  const SpeedRoundScreen({super.key, this.category, this.tournamentMode = false});

  final CategoryItem? category;
  final bool tournamentMode;

  static const int roundSeconds = 60;
  static const int rewardThreshold = 10;
  static const int rewardAmount = 50;
  static const List<String> _difficulties = ['Kolay', 'Orta', 'Zor', 'Imkansız'];

  /// Bu haftanın kategorisi (ISO hafta numarasına göre standart listeden).
  static CategoryItem weeklyCategory([DateTime? now]) {
    final weekKey = LeagueService.weekKey(now ?? DateTime.now());
    final week = int.tryParse(weekKey.split('W').last) ?? 0;
    final list = AppCategories.categories;
    return list[week % list.length];
  }

  /// Yerel önbellekten (internet gerektirmeden) kategori soruları; yoksa yerleşik çevrimdışı sorular.
  /// Hız turu ve arkadaş turnuvası aynı kaynağı kullanır.
  static Future<List<Question>> loadRoundQuestions(String categoryName, String lang) async {
    final pool = <Question>[];
    final seen = <String>{};
    try {
      for (final diff in _difficulties) {
        final rows = await DatabaseHelper.instance.getRecycledCachedQuestions(
          category: categoryName,
          difficulty: diff,
          languageCode: lang,
          count: 40,
        );
        for (final q in rows) {
          if (AiApiService.isCompactQuestion(q) && seen.add(q.question)) pool.add(q);
        }
      }
    } catch (e) {
      debugPrint('Hız turu önbellek okuma hatası: $e');
    }
    if (pool.isEmpty) {
      pool.addAll(OfflineQuizService.getFallbackQuestions(languageCode: lang, count: 30));
    }
    pool.shuffle(Random());
    return pool;
  }

  static String _bestKey(String weekKey) => 'speed_round_best_$weekKey';
  static String _rewardKey(String weekKey) => 'speed_round_rewarded_$weekKey';

  @override
  State<SpeedRoundScreen> createState() => _SpeedRoundScreenState();
}

class _SpeedRoundScreenState extends State<SpeedRoundScreen> with WidgetsBindingObserver {
  late final CategoryItem _category = widget.category ?? SpeedRoundScreen.weeklyCategory();
  late final String _weekKey = LeagueService.weekKey(DateTime.now());

  _Phase _phase = _Phase.idle;
  List<Question> _questions = [];
  int _index = 0;
  int _score = 0;
  int _timeLeft = SpeedRoundScreen.roundSeconds;
  int _best = 0;
  int? _selected; // Cevaplanan şık (geri bildirim süresince kilitli)
  bool _rewardedNow = false;
  bool _paused = false;

  Timer? _timer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  // Uygulama arka plana gidince süreyi durdur, öne gelince devam ettir
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != _Phase.running) return;
    if (state == AppLifecycleState.resumed) {
      if (_paused) {
        _paused = false;
        _startTimer();
      }
    } else if (!_paused) {
      _paused = true;
      _timer?.cancel();
    }
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(SpeedRoundScreen._bestKey(_weekKey)) ?? 0);
  }

  Future<void> _start() async {
    if (_phase == _Phase.loading || _phase == _Phase.running) return;
    final lang = context.locale.languageCode;
    HapticService.selection();
    setState(() => _phase = _Phase.loading);

    final qs = await SpeedRoundScreen.loadRoundQuestions(_category.name, lang);
    if (!mounted) return;
    if (qs.isEmpty) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    if (!widget.tournamentMode) {
      final paid = await TokenService.spendTokens(TokenEconomy.speedRoundEntryCost,
          reason: 'speed_round_entry');
      if (!mounted) return;
      if (!paid) {
        setState(() => _phase = _Phase.idle);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('quiz.not_enough_tokens'.tr(args: [TokenEconomy.speedRoundEntryCost.toString()])),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
    }
    setState(() {
      _questions = qs;
      _index = 0;
      _score = 0;
      _timeLeft = SpeedRoundScreen.roundSeconds;
      _selected = null;
      _rewardedNow = false;
      _paused = false;
      _phase = _Phase.running;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) _endRound();
    });
  }

  void _answer(int i) {
    if (_phase != _Phase.running || _selected != null) return;
    final correct = i == _questions[_index].correctIndex;
    setState(() {
      _selected = i;
      if (correct) _score++;
    });
    if (correct) {
      HapticService.correct();
      SoundService.playCorrect();
    } else {
      HapticService.wrong();
      SoundService.playWrong();
    }
    // Kısa geri bildirimden sonra bir sonraki soruya geç (yanlış cevap oyunu bitirmez)
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 350), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted || _phase != _Phase.running) return;
    setState(() {
      _selected = null;
      if (_index + 1 >= _questions.length) {
        _questions.shuffle(Random());
        _index = 0;
      } else {
        _index++;
      }
    });
  }

  Future<void> _endRound() async {
    if (_phase != _Phase.running) return;
    _timer?.cancel();
    _flashTimer?.cancel();
    final score = _score;
    setState(() {
      _phase = _Phase.finished;
      _selected = null;
    });
    HapticService.medium();
    // Turnuva turu: haftalık skor/ödül yazılmaz; sonuç bitiş ekranındaki butonla döndürülür
    if (widget.tournamentMode) return;

    final prefs = await SharedPreferences.getInstance();
    final bestKey = SpeedRoundScreen._bestKey(_weekKey);
    final prevBest = prefs.getInt(bestKey) ?? 0;
    if (score > prevBest) await prefs.setInt(bestKey, score);
    final best = max(prevBest, score);

    // Doğru cevap başına jeton (giriş ücreti düşüldükten sonra)
    final payout = score * TokenEconomy.speedRoundTokensPerCorrect;
    if (payout > 0) {
      await TokenService.addTokens(payout, source: 'speed_round_play');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('token.reward_flat'.tr(args: ['$payout'])),
          backgroundColor: Colors.indigo,
        ));
      }
    }

    // Haftada bir kez: en iyi skor eşiğe ulaşınca ödül
    var rewarded = false;
    final rewardKey = SpeedRoundScreen._rewardKey(_weekKey);
    if (best >= SpeedRoundScreen.rewardThreshold && !(prefs.getBool(rewardKey) ?? false)) {
      await prefs.setBool(rewardKey, true);
      await TokenService.addTokens(SpeedRoundScreen.rewardAmount, source: 'speed_round');
      rewarded = true;
    }

    if (!mounted) return;
    setState(() {
      _best = best;
      _rewardedNow = rewarded;
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
              'speed_round.title'.tr(),
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
      case _Phase.running:
        return _buildRunning(lang);
      case _Phase.finished:
        return _buildFinished();
    }
  }

  Widget _buildIntro() {
    final catName = _category.key.tr();
    final isTournament = widget.tournamentMode;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 72, color: _category.color),
            const SizedBox(height: 16),
            Text(
              'speed_round.subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            GlassContainer(
              opacity: 0.1,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                isTournament
                    ? 'tournament.round_category'.tr(args: [catName])
                    : 'speed_round.weekly_category'.tr(args: [catName]),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _category.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            if (!isTournament) ...[
              const SizedBox(height: 12),
              Text(
                '${'speed_round.best'.tr()}: $_best',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 28),
            if (_phase == _Phase.loading)
              const CircularProgressIndicator(color: Colors.white)
            else
              _buildPrimaryButton('speed_round.start'.tr(), _start),
          ],
        ),
      ),
    );
  }

  Widget _buildRunning(String lang) {
    final q = _questions[_index];
    final options = q.getLocalizedOptions(lang);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statTile('speed_round.score'.tr(), '$_score', const Color(0xFF96CEB4))),
            const SizedBox(width: 8),
            Expanded(child: _statTile('${SpeedRoundScreen.roundSeconds}s', '$_timeLeft', const Color(0xFFFECA57))),
            const SizedBox(width: 8),
            Expanded(child: _statTile('speed_round.best'.tr(), '$_best', const Color(0xFF45B7D1))),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _timeLeft / SpeedRoundScreen.roundSeconds,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            color: _timeLeft <= 10 ? const Color(0xFFFF6B6B) : const Color(0xFF96CEB4),
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildOption(options[i], i, q.correctIndex),
          ),
        ),
        const SizedBox(height: 12),
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
              'speed_round.time_up'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            GlassContainer(
              opacity: 0.1,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'speed_round.score'.tr(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_score',
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'speed_round.best'.tr()}: $_best',
                    style: const TextStyle(color: Color(0xFFFECA57), fontWeight: FontWeight.w700),
                  ),
                  if (_rewardedNow) ...[
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD56B), size: 20),
                        SizedBox(width: 6),
                        Text(
                          '+${SpeedRoundScreen.rewardAmount}',
                          style: TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (widget.tournamentMode)
              _buildPrimaryButton(
                'tournament.submit_round'.tr(),
                () => Navigator.of(context).pop(_score),
              )
            else
              _buildPrimaryButton('speed_round.play_again'.tr(), _start),
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
}
