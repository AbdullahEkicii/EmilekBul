import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'glass_alert_dialog.dart';

import '../services/haptic_service.dart';
import '../services/retention_engine.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import 'confetti_burst.dart';

/// Ana ekrandaki "Günlük hedef + ücretsiz sandık" kartı.
/// Süre sayacı zaman damgasından hesaplanır (uygulama kapalıyken de ilerler).
class DailyGoalCard extends StatefulWidget {
  /// Jeton bakiyesi değiştiğinde (sandık açılınca) üst ekranın yenilenmesi için.
  final VoidCallback? onTokensChanged;

  const DailyGoalCard({super.key, this.onTokensChanged});

  @override
  State<DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<DailyGoalCard> with WidgetsBindingObserver {
  GoalState _goal = const GoalState(0, 3, false);
  int _weeklyDays = 0;
  bool _weeklyClaimed = false;
  ChestState _chest = const ChestState(false, Duration.zero);
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _chest.ready) return;
      final left = _chest.remaining - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        _reload();
      } else {
        setState(() => _chest = ChestState(false, left));
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final goal = await RetentionEngine.getGoal();
    final chest = await RetentionEngine.getChest();
    final (days, claimed) = await RetentionEngine.getWeekly();
    if (!mounted) return;
    setState(() {
      _goal = goal;
      _chest = chest;
      _weeklyDays = days;
      _weeklyClaimed = claimed;
    });
  }

  Future<void> _claim(Future<int> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      final tokens = await action();
      if (tokens > 0 && mounted) {
        HapticService.celebrate();
        SoundService.playCorrect();
        ConfettiBurst.show(context);
        widget.onTokensChanged?.call();
        await _showReward(tokens);
      }
    } finally {
      _busy = false;
      await _reload();
    }
  }

  Future<void> _showReward(int tokens) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        backgroundColor: AppColors.dialogSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.redeem_rounded, color: AppColors.goldSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text('retention_hub.reward_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'retention_hub.reward_tokens'.tr(args: ['$tokens']),
          style: const TextStyle(
              color: AppColors.goldSoft, fontSize: 26, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('retention_hub.great'.tr()),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    final progress = _goal.target == 0 ? 0.0 : (_goal.progress / _goal.target).clamp(0.0, 1.0);
    final goalDone = _goal.reached;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.22),
            AppColors.surfaceElevated.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      color: goalDone ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    ),
                    Icon(
                      goalDone ? Icons.check_rounded : Icons.flag_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('retention_hub.goal_title'.tr(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      goalDone
                          ? 'retention_hub.goal_done'.tr()
                          : 'retention_hub.goal_progress'
                              .tr(args: ['${_goal.progress}', '${_goal.target}']),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (_goal.claimable)
                _pillButton('retention_hub.open'.tr(), () => _claim(RetentionEngine.claimGoalChest)),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: _weeklyClaimed ? Colors.white38 : const Color(0xFF34D399), size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('retention_hub.weekly_title'.tr(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      _weeklyClaimed
                          ? 'retention_hub.weekly_done'.tr()
                          : 'retention_hub.weekly_progress'.tr(args: [
                              '$_weeklyDays',
                              '${RetentionEngine.weeklyTargetDays}'
                            ]),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!_weeklyClaimed && _weeklyDays >= RetentionEngine.weeklyTargetDays)
                _pillButton('retention_hub.open'.tr(), () => _claim(RetentionEngine.claimWeeklyChest)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFBBF24), size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('retention_hub.chest_title'.tr(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      _chest.ready
                          ? 'retention_hub.chest_ready'.tr()
                          : 'retention_hub.chest_next'.tr(args: [_fmt(_chest.remaining)]),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (_chest.ready)
                _pillButton('retention_hub.open'.tr(), () => _claim(RetentionEngine.claimTimerChest)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFFBBF24),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF1F1300), fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    );
  }
}
