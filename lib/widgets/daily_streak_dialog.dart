import '../services/haptic_service.dart';
import 'confetti_burst.dart';
import 'package:flutter/material.dart';
import '../services/performance_service.dart';
import '../services/streak_service.dart';
import '../services/sound_service.dart';
import '../services/achievement_service.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'glass_container.dart';

class DailyStreakDialog extends StatefulWidget {
  final int currentStreak;
  final bool canClaimToday;
  final VoidCallback onClaimed;
  final int freezes;
  final int freezesUsed;
  final bool playedToday;

  const DailyStreakDialog({
    super.key,
    required this.currentStreak,
    required this.canClaimToday,
    required this.onClaimed,
    this.freezes = 0,
    this.freezesUsed = 0,
    this.playedToday = true,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentStreak,
    required bool canClaimToday,
    required VoidCallback onClaimed,
    int freezes = 0,
    int freezesUsed = 0,
    bool playedToday = true,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: PerformanceService.blur(sigma: 8, child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: DailyStreakDialog(
                  currentStreak: currentStreak,
                  canClaimToday: canClaimToday,
                  onClaimed: onClaimed,
                  freezes: freezes,
                  freezesUsed: freezesUsed,
                  playedToday: playedToday,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<DailyStreakDialog> createState() => _DailyStreakDialogState();
}

class _DailyStreakDialogState extends State<DailyStreakDialog> with SingleTickerProviderStateMixin {
  bool _isClaiming = false;
  bool _claimed = false;
  int _earnedTokens = 0;
  int _milestoneStreak = 0;
  int _milestoneBonus = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    if (_isClaiming || !widget.canClaimToday || _claimed) return;

    setState(() {
      _isClaiming = true;
    });

    final earned = await StreakService.claimStreakReward();
    SoundService.playCorrect();

    if (mounted) {
      setState(() {
        _isClaiming = false;
        _claimed = true;
        _earnedTokens = earned;
      });
      widget.onClaimed();
      if (StreakService.lastMilestoneBonus > 0) {
        _milestoneStreak = StreakService.lastMilestoneStreak;
        _milestoneBonus = StreakService.lastMilestoneBonus;
        StreakService.lastMilestoneBonus = 0;
        ConfettiBurst.show(context);
        HapticService.celebrate();
      }
      await AchievementService.checkAndUnlockStreakAchievements(widget.currentStreak + 1, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStreak = _claimed ? widget.currentStreak + 1 : widget.currentStreak;

    return GlassContainer(
      useBlur: true,
      scrim: true,
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Glowing Header Icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90 * scale,
                    height: 90 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.6 - (_pulseController.value * 0.2)),
                          blurRadius: 40 * scale,
                          spreadRadius: 15 * scale,
                        ),
                        BoxShadow(
                          color: Colors.deepOrange.withValues(alpha: 0.3),
                          blurRadius: 20 * scale,
                          spreadRadius: 5 * scale,
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: scale,
                    child: const Text(
                      '🔥',
                      style: TextStyle(fontSize: 64, shadows: [Shadow(color: Colors.black45, blurRadius: 10)]),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          Text(
            _claimed ? 'new_features.streak_claimed'.tr() : 'new_features.streak_title'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _claimed
                ? 'new_features.streak_reward_added'.tr(namedArgs: {'tokens': _earnedTokens.toString()})
                : 'new_features.streak_prompt'.tr(namedArgs: {'streak': effectiveStreak.toString()}),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (_claimed && _milestoneBonus > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
              ),
              child: Text(
                'retention_hub.milestone'.tr(args: ['$_milestoneStreak', '$_milestoneBonus']),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
          if (widget.freezesUsed > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
              ),
              child: Text(
                'daily_streak.freeze_used'.tr(args: [widget.freezesUsed.toString()]),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❄️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'daily_streak.freezes_owned'.tr(args: [widget.freezes.toString(), StreakService.maxFreezes.toString()]),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 7-day reward roadmap
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                final reward = StreakService.streakRewards[index];
                final isPassed = dayNum <= effectiveStreak;
                final isCurrentTarget = widget.canClaimToday && !_claimed && dayNum == (widget.currentStreak + 1);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrentTarget
                        ? Colors.orange.withValues(alpha: 0.3)
                        : (isPassed
                            ? Colors.green.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentTarget
                          ? Colors.orangeAccent
                          : (isPassed ? Colors.greenAccent : Colors.white12),
                      width: isCurrentTarget ? 2 : 1,
                    ),
                    boxShadow: isCurrentTarget
                        ? [BoxShadow(color: Colors.orangeAccent.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'daily_streak.day_num'.tr(args: [dayNum.toString()]),
                        style: TextStyle(
                          color: isCurrentTarget
                              ? Colors.orangeAccent
                              : (isPassed ? Colors.greenAccent : Colors.white70),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPassed ? '✅' : '🪙',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+$reward',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),

          if (widget.canClaimToday && !_claimed && !widget.playedToday) ...[
            Text(
              'daily_streak.play_to_claim'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, height: 1.35),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('daily_streak.play_now'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ] else
          // Action Button
          if (widget.canClaimToday && !_claimed)
            ElevatedButton(
              onPressed: _isClaiming ? null : _handleClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
              ),
              child: _isClaiming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      'new_features.streak_claim_today'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            )
          else
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _claimed ? 'new_features.wheel_awesome'.tr() : 'new_features.streak_ok'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
