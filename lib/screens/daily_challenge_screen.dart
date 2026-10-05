import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_categories.dart';
import '../services/daily_challenge_service.dart';
import '../services/interstitial_ad_manager.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../services/streak_service.dart';
import '../services/user_service.dart';
import '../utils/app_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/navigation_buttons.dart';
import 'quiz_screen.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  bool _loading = true;
  bool _starting = false;
  DailyChallengeResult? _result;
  (int, int)? _rank;
  List<DailyChallengeEntry> _board = [];

  String get _lang => context.locale.languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _board.isEmpty && _result == null) _load();
  }

  Future<void> _load() async {
    try {
      final result = await DailyChallengeService.getMyResult(_lang);
      final board = await DailyChallengeService.leaderboard(_lang);
      final rank = result != null ? await DailyChallengeService.myRank(_lang, result) : null;
      if (!mounted) return;
      setState(() {
        _result = result;
        _board = board;
        _rank = rank;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Daily challenge load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _categoryName() {
    final key = AppCategories.getCategoryKey(DailyChallengeService.todayCategory());
    return key.isNotEmpty ? key.tr() : DailyChallengeService.todayCategory();
  }

  Future<void> _start() async {
    if (_starting) return;
    if (!await AppUtils.hasInternetConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('errors.no_internet_ai'.tr())));
      }
      return;
    }
    setState(() => _starting = true);
    try {
      final questions = await DailyChallengeService.getOrCreateQuestions(_lang);
      if (!mounted) return;
      setState(() => _starting = false);
      final watch = Stopwatch()..start();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (quizContext) => QuizScreen(
            questions: questions,
            category: DailyChallengeService.todayCategory(),
            difficulty: DailyChallengeService.difficulty,
            duration: 35,
            onFinished: (answers, score, {botScore, botName, botAvatar, playerFinishedFirst}) {
              watch.stop();
              final pattern = List<bool>.generate(
                questions.length,
                (i) => i < answers.length && answers[i] == questions[i].correctIndex,
              );
              InterstitialAdManager.onTestFinished(
                source: 'daily',
                onDone: () async {
                  if (Navigator.of(quizContext).canPop()) Navigator.of(quizContext).pop();
                  await _submit(pattern, watch.elapsedMilliseconds);
                },
              );
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Daily challenge start error: $e');
      if (mounted) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('duel.start_error'.tr())));
      }
    }
  }

  Future<void> _submit(List<bool> pattern, int timeMs) async {
    final ok = await DailyChallengeService.submit(lang: _lang, pattern: pattern, timeMs: timeMs);
    NotificationService.markPlayedToday();
    StreakService.markQuizPlayedToday();
    if (!mounted) return;
    if (ok) {
      final correct = pattern.where((c) => c).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('daily_challenge.reward'.tr(args: [(correct * DailyChallengeService.tokensPerCorrect).toString()])),
          backgroundColor: Colors.green,
        ),
      );
    }
    setState(() => _loading = true);
    await _load();
  }

  void _share() {
    final result = _result;
    if (result == null) return;
    final rank = _rank;
    final text = 'daily_challenge.share_text'.tr(args: [
      'app_title'.tr(),
      DailyChallengeService.todayKey(),
      result.correct.toString(),
      result.total.toString(),
      DailyChallengeService.patternEmoji(result.pattern),
      rank != null ? '#${rank.$1}/${rank.$2}' : '-',
    ]);
    ShareService.shareText(context, text: text, contentType: 'daily_challenge');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'daily_challenge.title'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        children: [
                          _result == null ? _buildStartCard() : _buildResultCard(_result!),
                          const SizedBox(height: 18),
                          Text(
                            'daily_challenge.leaderboard'.tr(),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (_board.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'daily_challenge.empty'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                              ),
                            )
                          else
                            ..._buildBoardRows(),
                        ],
                      ),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: MyNativeAd(height: 65),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartCard() {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            _categoryName(),
            style: const TextStyle(color: Color(0xFFFFD56B), fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'daily_challenge.rules'.tr(args: [
              DailyChallengeService.questionCount.toString(),
              DailyChallengeService.tokensPerCorrect.toString(),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _starting ? null : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F43),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _starting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text('daily_challenge.start'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(DailyChallengeResult result) {
    final rank = _rank;
    final seconds = (result.timeMs / 1000).toStringAsFixed(1);
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '${result.correct}/${result.total}',
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(DailyChallengeService.patternEmoji(result.pattern), style: const TextStyle(fontSize: 24, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text(
            rank != null
                ? 'daily_challenge.rank'.tr(args: [rank.$1.toString(), rank.$2.toString(), seconds])
                : '${seconds}s',
            style: const TextStyle(color: Color(0xFFFFD56B), fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'daily_challenge.come_back'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _share,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.ios_share_rounded),
              label: Text('share.button'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBoardRows() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return List.generate(_board.length, (i) {
      final e = _board[i];
      final isMe = e.uid == myUid;
      final hasAvatar = UserService.hasAvatar(e.avatarIndex);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFF9F43).withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? const Color(0xFFFF9F43).withValues(alpha: 0.7) : Colors.white12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: hasAvatar
                  ? ResizeImage(AssetImage(UserService.getAvatarPath(e.avatarIndex)), width: 64, height: 64)
                  : null,
              child: hasAvatar ? null : const Icon(Icons.person_rounded, size: 16, color: Colors.white70),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppUtils.localizeUsername(e.username),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: isMe ? FontWeight.w900 : FontWeight.w600),
              ),
            ),
            Text(
              '${e.correct}/${DailyChallengeService.questionCount} · ${(e.timeMs / 1000).toStringAsFixed(1)}s',
              style: const TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    });
  }
}
