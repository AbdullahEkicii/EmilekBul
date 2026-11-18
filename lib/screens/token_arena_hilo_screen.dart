import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import '../theme/app_theme.dart';
import 'token_arena_common.dart';

/// Yüksek mi Düşük mü: 3 tur kart tahmini (eşitlikte kasa kazanır, 1.8x ödeme).
class TokenArenaHiLoScreen extends StatefulWidget {
  final int initialStake;

  const TokenArenaHiLoScreen({
    super.key,
    this.initialStake = TokenEconomy.miniGameStake,
  });

  @override
  State<TokenArenaHiLoScreen> createState() => _TokenArenaHiLoScreenState();
}

class _TokenArenaHiLoScreenState extends State<TokenArenaHiLoScreen> {
  final _rng = Random();
  late int _stake;
  int _balance = 0;

  bool _playing = false;
  bool? _won;
  int _payout = 0;
  int _round = 0;
  int _card = 7;
  int _suitIndex = 0;
  String? _statusHint;

  static const _suits = ['♠', '♥', '♦', '♣'];

  @override
  void initState() {
    super.initState();
    _stake = widget.initialStake;
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final bal = await loadArenaBalance();
    if (mounted) setState(() => _balance = bal);
  }

  Future<void> _start() async {
    if (!await arenaStake(context, 'hilo', stake: _stake)) return;
    setState(() {
      _playing = true;
      _won = null;
      _payout = 0;
      _round = 0;
      _card = TokenArenaRules.drawCard(_rng);
      _suitIndex = _rng.nextInt(_suits.length);
      _statusHint = null;
    });
    _refreshBalance();
  }

  Future<void> _guess(bool higher) async {
    final next = TokenArenaRules.drawCard(_rng);
    final nextSuit = _rng.nextInt(_suits.length);
    final ok = TokenArenaRules.hiLoGuessCorrect(
      current: _card,
      next: next,
      guessHigher: higher,
    );

    if (!ok) {
      final isTie = next == _card;
      setState(() {
        _card = next;
        _suitIndex = nextSuit;
        _playing = false;
        _won = false;
        _payout = 0;
        _statusHint = isTie ? 'mg.tie_house_wins'.tr() : null;
      });
      await arenaFinish('hilo', false, stake: _stake);
      _refreshBalance();
      return;
    }

    final nextRound = _round + 1;
    if (nextRound >= TokenArenaRules.hiLoRounds) {
      final paid = await arenaFinish('hilo', true, stake: _stake);
      setState(() {
        _card = next;
        _suitIndex = nextSuit;
        _round = nextRound;
        _playing = false;
        _won = true;
        _payout = paid;
      });
      _refreshBalance();
      return;
    }

    SoundService.playCorrect();
    HapticService.light();
    setState(() {
      _card = next;
      _suitIndex = nextSuit;
      _round = nextRound;
    });
  }

  String _rank(int v) => const {1: 'A', 11: 'J', 12: 'Q', 13: 'K'}[v] ?? '$v';

  @override
  Widget build(BuildContext context) {
    final suit = _suits[_suitIndex];
    final isRed = suit == '♥' || suit == '♦';
    final cardColor = isRed ? AppColors.danger : const Color(0xFF0F172A);

    return ArenaScaffold(
      title: 'mg.higher_lower'.tr(),
      balance: _balance,
      accentColor: AppColors.indigoLight,
      ruleSummary: 'mg.higher_lower_rule'.tr(),
      onBalanceTap: () => openTokenEarnScreen(context, onReturned: _refreshBalance),
      child: Column(
        children: [
          _buildRoundStepper(),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: ValueKey('$_card-$_suitIndex-$_round-$_won'),
              width: 170,
              height: 235,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _won == true
                      ? AppColors.success
                      : (_won == false
                          ? AppColors.danger
                          : AppColors.indigoLight),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_won == false
                            ? AppColors.danger
                            : AppColors.indigo)
                        .withValues(alpha: 0.38),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      children: [
                        Text(
                          _rank(_card),
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: cardColor,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          suit,
                          style: TextStyle(fontSize: 18, color: cardColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        _rank(_card),
                        style: GoogleFonts.poppins(
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          color: cardColor,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        suit,
                        style: TextStyle(fontSize: 28, color: cardColor),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '${_rank(_card)} $suit',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cardColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _statusHint ?? 'mg.tie_house_note'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _statusHint != null
                  ? AppColors.danger
                  : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          if (_won != null) ...[
            ArenaResultBanner(
              won: _won!,
              stake: _stake,
              payoutAmount: _payout,
              currentBalance: _balance,
              onEarnTokens: () =>
                  openTokenEarnScreen(context, onReturned: _refreshBalance),
            ),
            const SizedBox(height: 12),
          ],
          if (!_playing) ...[
            ArenaStakeSelector(
              selectedStake: _stake,
              onSelected: (v) => setState(() => _stake = v),
              accentColor: AppColors.indigoLight,
            ),
            const SizedBox(height: 12),
            ArenaPlayButton(
              label: 'mg.play'.tr(args: ['$_stake']),
              onPressed: _start,
              color: AppColors.indigo,
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildGuessButton(
                    icon: Icons.arrow_downward_rounded,
                    label: 'mg.lower'.tr(),
                    color: AppColors.danger,
                    onTap: () => _guess(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGuessButton(
                    icon: Icons.arrow_upward_rounded,
                    label: 'mg.higher'.tr(),
                    color: AppColors.emerald,
                    onTap: () => _guess(true),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRoundStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(TokenArenaRules.hiLoRounds, (i) {
        final done = i < _round;
        final active = _playing && i == _round;
        final color = done
            ? AppColors.success
            : (active ? AppColors.indigoLight : Colors.white24);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: done || active ? 0.22 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color),
          ),
          child: Text(
            'mg.round'.tr(args: ['${i + 1}', '${TokenArenaRules.hiLoRounds}']),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: done || active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGuessButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: color.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
