import 'package:flutter/material.dart';
import '../services/performance_service.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../services/analytics_service.dart';
import '../services/streak_service.dart';
import '../services/token_service.dart';
import 'glass_container.dart';
import 'rewarded_ad_manager.dart';

/// Bozulan seriyi ödüllü reklam veya jetonla geri alma teklifi.
/// Seri kurtarıldıysa true döner.
class StreakRescueDialog extends StatefulWidget {
  final int lostStreak;
  final int missedDays;

  const StreakRescueDialog({super.key, required this.lostStreak, required this.missedDays});

  static Future<bool> show(BuildContext context, {required int lostStreak, required int missedDays}) async {
    AnalyticsService.logStreakRescueOffered(streak: lostStreak, missed: missedDays);
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Opacity(
          opacity: anim1.value,
          child: Transform.scale(
            scale: 0.9 + 0.1 * anim1.value,
            child: PerformanceService.blur(sigma: 8, child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: StreakRescueDialog(lostStreak: lostStreak, missedDays: missedDays),
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  State<StreakRescueDialog> createState() => _StreakRescueDialogState();
}

class _StreakRescueDialogState extends State<StreakRescueDialog> {
  final RewardedAdManager _adManager = RewardedAdManager();
  bool _adReady = false;
  bool _busy = false;

  bool get _adAllowed => widget.missedDays <= StreakService.rescueMaxMissedDaysForAd;

  @override
  void initState() {
    super.initState();
    if (_adAllowed) {
      _adManager.loadAd(
        onAdLoaded: () {
          if (mounted) setState(() => _adReady = true);
        },
      );
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _rescueWithTokens() async {
    if (_busy) return;
    setState(() => _busy = true);
    final tokens = await TokenService.getTokenAmount();
    if (tokens < StreakService.rescueTokenPrice) {
      if (mounted) setState(() => _busy = false);
      _toast('streak_rescue.not_enough_tokens'.tr());
      return;
    }
    final ok = await StreakService.rescueStreak(viaTokens: true);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _rescueWithAd() async {
    if (_busy) return;
    final cooldown = await RewardedAdManager.getRemainingCooldown();
    if (cooldown > Duration.zero) {
      final mm = cooldown.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = cooldown.inSeconds.remainder(60).toString().padLeft(2, '0');
      final t = cooldown.inHours > 0 ? '${cooldown.inHours}:$mm:$ss' : '$mm:$ss';
      _toast('token.reward_ad_cooldown'.tr(args: [t]));
      return;
    }
    if (!_adManager.isReady) {
      _toast('common.ad_not_ready'.tr());
      return;
    }
    setState(() => _busy = true);
    var rewarded = false;
    _adManager.showAd(onRewarded: () async {
      if (rewarded) return;
      rewarded = true;
      await RewardedAdManager.recordAdWatched();
      final ok = await StreakService.rescueStreak(viaTokens: false);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _busy = false);
      }
    });
    // Reklam ödül vermeden kapanırsa tekrar denenebilsin
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !rewarded) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final price = StreakService.rescueTokenPrice;
    return GlassContainer(
      useBlur: true,
      scrim: true,
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💔', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            'streak_rescue.title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'streak_rescue.body'.tr(args: [widget.lostStreak.toString()]),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 20),
          if (_adAllowed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _rescueWithAd,
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: Text(
                  'streak_rescue.watch_ad'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _adReady ? Colors.orangeAccent : Colors.orangeAccent.withValues(alpha: 0.5),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          if (_adAllowed) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _rescueWithTokens,
              icon: const Text('🪙', style: TextStyle(fontSize: 16)),
              label: Text(
                'streak_rescue.pay_tokens'.tr(args: [price.toString()]),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(
              'streak_rescue.no_thanks'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
