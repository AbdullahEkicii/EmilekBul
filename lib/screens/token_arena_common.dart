import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/haptic_service.dart';
import '../services/interstitial_ad_manager.dart';
import '../services/rewarded_boost.dart';
import '../services/sound_service.dart';
import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import '../services/token_service.dart';
import '../theme/app_theme.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/rewarded_ad_manager.dart';
import 'token_screen.dart';

/// Güvenli şekilde mevcut jeton bakiyesini okur (test ortamında 0 döner).
Future<int> loadArenaBalance() async {
  try {
    return await TokenService.getTokenAmount();
  } catch (_) {
    return 0;
  }
}

/// TokenScreen'e hızlı geçiş (reklam/görev ile jeton kazanma).
void openTokenEarnScreen(BuildContext context, {VoidCallback? onReturned}) {
  HapticService.selection();
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const TokenScreen()))
      .then((_) => onReturned?.call());
}

/// Mini oyunlar için ortak koyu neon arcade iskeleti, bakiye rozeti ve kural bandı.
class ArenaScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final int? balance;
  final String? ruleSummary;
  final VoidCallback? onBalanceTap;
  final Color accentColor;

  const ArenaScaffold({
    super.key,
    required this.title,
    required this.child,
    this.balance,
    this.ruleSummary,
    this.onBalanceTap,
    this.accentColor = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          if (balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ArenaBalancePill(
                  balance: balance!,
                  onTap: onBalanceTap ?? () => openTokenEarnScreen(context),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundTop,
              AppColors.backgroundBottom,
              AppColors.scaffoldGradientStart,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (ruleSummary != null && ruleSummary!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: accentColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ruleSummary!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: MyNativeAd(height: 65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Üst barda veya hub'da canlı jeton bakiyesi + "+" kısayolu.
class ArenaBalancePill extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;

  const ArenaBalancePill({
    super.key,
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0.22),
              AppColors.amberDark.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              color: AppColors.gold,
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              '$balance',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.add_circle_rounded,
              color: AppColors.gold.withValues(alpha: 0.9),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

/// 25 / 50 / 100 jeton bahis kademesi seçici.
class ArenaStakeSelector extends StatelessWidget {
  final int selectedStake;
  final ValueChanged<int> onSelected;
  final bool enabled;
  final double? previewMultiplier;
  final Color accentColor;

  const ArenaStakeSelector({
    super.key,
    required this.selectedStake,
    required this.onSelected,
    this.enabled = true,
    this.previewMultiplier,
    this.accentColor = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    final mult = previewMultiplier ?? TokenEconomy.miniGamePayoutMultiplier;
    final maxWin = (selectedStake * mult).floor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'mg.select_stake'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'mg.max_win_label'.tr(args: ['$maxWin']),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: TokenEconomy.arenaStakes.map((tier) {
              final active = tier == selectedStake;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: enabled
                        ? () {
                            HapticService.selection();
                            onSelected(tier);
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: active
                            ? LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withValues(alpha: 0.72),
                                ],
                              )
                            : null,
                        color: active
                            ? null
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active
                              ? accentColor
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.monetization_on_rounded,
                            size: 14,
                            color: active ? Colors.black87 : AppColors.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$tier',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: active ? Colors.black87 : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Seçilen bahsi düşer; yetersizse Jeton Kazan kısayollu uyarı gösterir.
Future<bool> arenaStake(
  BuildContext context,
  String gameId, {
  int stake = TokenEconomy.miniGameStake,
}) async {
  try {
    final ok = await TokenService.stakeMiniGame(gameId, stake: stake);
    if (!ok && context.mounted) {
      HapticService.wrong();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.dialogSurface,
          content: Text(
            'quiz.not_enough_tokens'.tr(),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'mg.earn_tokens_cta'.tr(),
            textColor: AppColors.gold,
            onPressed: () => openTokenEarnScreen(context),
          ),
        ),
      );
    } else if (ok) {
      HapticService.medium();
    }
    return ok;
  } catch (e) {
    debugPrint('arenaStake error: $e');
    return false;
  }
}

/// Tur bittiğinde kazancı öder (varsa) ve ses/titreşim geri bildirimi verir.
Future<int> arenaFinish(
  String gameId,
  bool won, {
  int stake = TokenEconomy.miniGameStake,
  int? customPayout,
}) async {
  try {
    final payoutAmount =
        customPayout ?? (won ? TokenArenaRules.payout(stake) : 0);
    if (payoutAmount > 0) {
      await TokenService.payMiniGame(
        gameId,
        stake: stake,
        customPayout: payoutAmount,
      );
      SoundService.playCorrect();
      HapticService.celebrate();
      unawaited(
        InterstitialAdManager.onMiniGameRoundFinished(source: 'arena_$gameId'),
      );
      return payoutAmount;
    } else {
      SoundService.playWrong();
      HapticService.wrong();
      unawaited(
        InterstitialAdManager.onMiniGameRoundFinished(source: 'arena_$gameId'),
      );
      return 0;
    }
  } catch (e) {
    debugPrint('arenaFinish error: $e');
    return 0;
  }
}

/// Parlak birincil oyun aksiyon butonu.
class ArenaPlayButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const ArenaPlayButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkText = color.computeLuminance() > 0.55;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: onPressed != null
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.78)],
                )
              : null,
          color: onPressed == null ? Colors.white12 : null,
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: isDarkText ? Colors.black87 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tur sonucu bandı: kazanç/kayıp tutarı, anlık reklamla +30 jeton ve Jeton Kazan butonu.
class ArenaResultBanner extends StatefulWidget {
  final bool won;
  final int stake;
  final int? payoutAmount;
  final int? currentBalance;
  final VoidCallback? onEarnTokens;
  final VoidCallback? onTokensUpdated;

  const ArenaResultBanner({
    super.key,
    required this.won,
    this.stake = TokenEconomy.miniGameStake,
    this.payoutAmount,
    this.currentBalance,
    this.onEarnTokens,
    this.onTokensUpdated,
  });

  @override
  State<ArenaResultBanner> createState() => _ArenaResultBannerState();
}

class _ArenaResultBannerState extends State<ArenaResultBanner> {
  bool _watchingAd = false;
  bool _adClaimed = false;

  Future<void> _watchQuickAd() async {
    if (_watchingAd || _adClaimed) return;
    try {
      final cooldown = await RewardedAdManager.getRemainingCooldown();
      if (!mounted) return;
      if (cooldown > Duration.zero) {
        final mins =
            cooldown.inMinutes.remainder(60).toString().padLeft(2, '0');
        final secs =
            cooldown.inSeconds.remainder(60).toString().padLeft(2, '0');
        final formatted = cooldown.inHours > 0
            ? '${cooldown.inHours}:$mins:$secs'
            : '$mins:$secs';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('token.reward_ad_cooldown'.tr(args: [formatted]))),
        );
        return;
      }

      final boost = RewardedBoost();
      if (!boost.isReady) {
        boost.load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.ad_not_ready'.tr())),
        );
        return;
      }

      setState(() => _watchingAd = true);
      final ok = await boost.showAndWait();
      if (!mounted) return;
      if (ok) {
        await TokenService.addTokens(
          TokenEconomy.rewardedAdAmount,
          source: 'arena_recovery_ad',
        );
        HapticService.medium();
        if (!mounted) return;
        setState(() => _adClaimed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('token.reward_ad_success'.tr()),
            backgroundColor: Colors.indigo,
          ),
        );
        widget.onTokensUpdated?.call();
      }
      boost.load();
    } catch (e) {
      debugPrint('ArenaResultBanner rewarded ad error: $e');
    } finally {
      if (mounted) setState(() => _watchingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivePayout =
        widget.payoutAmount ?? (widget.won ? TokenArenaRules.payout(widget.stake) : 0);
    final isPartial = !widget.won && effectivePayout > 0 && effectivePayout < widget.stake;
    final accent = isPartial
        ? AppColors.amber
        : (widget.won ? AppColors.success : AppColors.danger);
    final showEarn = !widget.won ||
        (widget.currentBalance != null && widget.currentBalance! < widget.stake);

    final message = widget.won && effectivePayout > 0
        ? 'mg.win'.tr(args: ['$effectivePayout'])
        : (isPartial
            ? 'mg.partial_return'.tr(args: ['$effectivePayout', '${widget.stake}'])
            : 'mg.lose'.tr(args: ['${widget.stake}']));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.won
                    ? Icons.emoji_events_rounded
                    : (isPartial
                        ? Icons.replay_circle_filled_rounded
                        : Icons.close_rounded),
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (showEarn) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (!_adClaimed)
                  TextButton.icon(
                    onPressed: _watchingAd ? null : _watchQuickAd,
                    icon: const Icon(
                      Icons.ondemand_video_rounded,
                      size: 16,
                      color: AppColors.emerald,
                    ),
                    label: Text(
                      '${'token.watch_ad'.tr()} · +${TokenEconomy.rewardedAdAmount}',
                      style: GoogleFonts.poppins(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
                TextButton.icon(
                  onPressed:
                      widget.onEarnTokens ?? () => openTokenEarnScreen(context),
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  label: Text(
                    'mg.earn_tokens_cta'.tr(),
                    style: GoogleFonts.poppins(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
