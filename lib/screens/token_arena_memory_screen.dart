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

/// Hafıza Dizisi: 5 adımlı neon renk dizisini hatasız tekrarla (1.8x ödeme).
class TokenArenaMemoryScreen extends StatefulWidget {
  final int initialStake;

  const TokenArenaMemoryScreen({
    super.key,
    this.initialStake = TokenEconomy.miniGameStake,
  });

  @override
  State<TokenArenaMemoryScreen> createState() => _TokenArenaMemoryScreenState();
}

class _TokenArenaMemoryScreenState extends State<TokenArenaMemoryScreen> {
  static const _colors = [
    Color(0xFFFF453A),
    Color(0xFF0A84FF),
    Color(0xFF30D158),
    Color(0xFFFFD60A),
  ];
  static const _icons = [
    Icons.whatshot_rounded,
    Icons.bolt_rounded,
    Icons.eco_rounded,
    Icons.star_rounded,
  ];

  final _rng = Random();
  late int _stake;
  int _balance = 0;

  List<int> _seq = const [];
  int _step = 0;
  int? _lit;
  bool _showing = false;
  bool _playing = false;
  bool? _won;
  int _payout = 0;

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
    if (!await arenaStake(context, 'memory', stake: _stake)) return;
    final seq = TokenArenaRules.buildSequence(_rng);
    setState(() {
      _seq = seq;
      _step = 0;
      _playing = true;
      _showing = true;
      _won = null;
      _payout = 0;
    });
    _refreshBalance();

    for (final c in seq) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() => _lit = c);
      HapticService.selection();
      await Future.delayed(const Duration(milliseconds: 440));
      if (!mounted) return;
      setState(() => _lit = null);
    }
    if (mounted) setState(() => _showing = false);
  }

  Future<void> _tap(int color) async {
    if (!_playing || _showing) return;
    setState(() => _lit = color);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _lit = null);
    });

    if (!TokenArenaRules.memoryTapCorrect(_seq, _step, color)) {
      setState(() {
        _playing = false;
        _won = false;
        _payout = 0;
      });
      await arenaFinish('memory', false, stake: _stake);
      _refreshBalance();
      return;
    }

    final nextStep = _step + 1;
    if (nextStep >= _seq.length) {
      final paid = await arenaFinish('memory', true, stake: _stake);
      setState(() {
        _step = nextStep;
        _playing = false;
        _won = true;
        _payout = paid;
      });
      _refreshBalance();
      return;
    }

    SoundService.playCorrect();
    HapticService.light();
    setState(() => _step = nextStep);
  }

  @override
  Widget build(BuildContext context) {
    final promptText = _showing
        ? 'mg.watch'.tr()
        : (_playing ? 'mg.your_turn'.tr() : 'mg.memory_ready'.tr());

    return ArenaScaffold(
      title: 'mg.memory'.tr(),
      balance: _balance,
      accentColor: AppColors.purple,
      ruleSummary: 'mg.memory_rule'.tr(),
      onBalanceTap: () => openTokenEarnScreen(context, onReturned: _refreshBalance),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_showing ? AppColors.amber : AppColors.purple)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  promptText,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _showing ? AppColors.amber : Colors.white,
                  ),
                ),
                Row(
                  children: List.generate(TokenArenaRules.memoryLength, (i) {
                    final filled = i < _step;
                    return Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? AppColors.success : Colors.white24,
                        boxShadow: filled
                            ? [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: List.generate(_colors.length, (i) {
                final active = _lit == i;
                final base = _colors[i];
                return GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: active ? base : base.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: active ? Colors.white : base.withValues(alpha: 0.7),
                        width: active ? 3 : 1.5,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: base.withValues(alpha: 0.75),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        _icons[i],
                        size: active ? 52 : 40,
                        color: active ? Colors.white : base.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
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
              accentColor: AppColors.purple,
            ),
            const SizedBox(height: 12),
            ArenaPlayButton(
              label: 'mg.play'.tr(args: ['$_stake']),
              onPressed: _start,
              color: AppColors.purple,
            ),
          ],
        ],
      ),
    );
  }
}
