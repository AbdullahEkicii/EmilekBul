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

/// Mayınlı Kasa: 12 kasadan 4'ü mayınlı. Her elmas çarpanı büyütür; istediğin anda çekil!
class TokenArenaMinesScreen extends StatefulWidget {
  final int initialStake;

  const TokenArenaMinesScreen({
    super.key,
    this.initialStake = TokenEconomy.miniGameStake,
  });

  @override
  State<TokenArenaMinesScreen> createState() => _TokenArenaMinesScreenState();
}

class _TokenArenaMinesScreenState extends State<TokenArenaMinesScreen> {
  final _rng = Random();
  late int _stake;
  int _balance = 0;

  bool _playing = false;
  bool? _won;
  int _payout = 0;
  Set<int> _mines = const {};
  final Set<int> _revealed = <int>{};
  int? _explodedTile;

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
    if (!await arenaStake(context, 'mines', stake: _stake)) return;
    setState(() {
      _playing = true;
      _won = null;
      _payout = 0;
      _mines = TokenArenaRules.generateMines(_rng);
      _revealed.clear();
      _explodedTile = null;
    });
    _refreshBalance();
  }

  Future<void> _tapTile(int index) async {
    if (!_playing || _revealed.contains(index)) return;
    if (_mines.contains(index)) {
      setState(() {
        _playing = false;
        _explodedTile = index;
        _won = false;
        _payout = 0;
      });
      await arenaFinish('mines', false, stake: _stake);
      _refreshBalance();
      return;
    }

    SoundService.playCorrect();
    HapticService.light();
    setState(() => _revealed.add(index));

    if (_revealed.length >= TokenArenaRules.minesMaxSafePicks) {
      await _cashOut();
    }
  }

  Future<void> _cashOut() async {
    if (!_playing || _revealed.isEmpty) return;
    final winAmount = TokenArenaRules.minesPayout(_stake, _revealed.length);
    final paid = await arenaFinish(
      'mines',
      true,
      stake: _stake,
      customPayout: winAmount,
    );
    if (!mounted) return;
    setState(() {
      _playing = false;
      _won = true;
      _payout = paid;
    });
    _refreshBalance();
  }

  @override
  Widget build(BuildContext context) {
    final safeCount = _revealed.length;
    final currentCashout = TokenArenaRules.minesPayout(_stake, safeCount);

    return ArenaScaffold(
      title: 'mg.mines'.tr(),
      balance: _balance,
      accentColor: AppColors.emerald,
      ruleSummary: 'mg.mines_rule'.tr(),
      onBalanceTap: () => openTokenEarnScreen(context, onReturned: _refreshBalance),
      child: Column(
        children: [
          _buildMultiplierLadder(safeCount),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: TokenArenaRules.minesTotalTiles,
              itemBuilder: (context, i) => _buildTile(i),
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
              previewMultiplier: TokenArenaRules.minesMultipliers.last,
              onSelected: (v) => setState(() => _stake = v),
              accentColor: AppColors.emerald,
            ),
            const SizedBox(height: 12),
            ArenaPlayButton(
              label: 'mg.play'.tr(args: ['$_stake']),
              onPressed: _start,
              color: AppColors.emerald,
            ),
          ] else ...[
            ArenaPlayButton(
              label: safeCount == 0
                  ? 'mg.mines_pick_hint'.tr()
                  : 'mg.cash_out'.tr(args: ['$currentCashout']),
              onPressed: safeCount == 0 ? null : _cashOut,
              color: AppColors.gold,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiplierLadder(int safeCount) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TokenArenaRules.minesMultipliers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final step = i + 1;
          final mult = TokenArenaRules.minesMultipliers[i];
          final hit = safeCount >= step;
          final next = _playing && safeCount + 1 == step;
          final color = hit
              ? AppColors.emerald
              : (next ? AppColors.gold : Colors.white24);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: hit || next ? 0.22 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${mult.toStringAsFixed(2)}x',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hit || next ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTile(int index) {
    final isSafeRevealed = _revealed.contains(index);
    final isExploded = _explodedTile == index;
    final revealAll = !_playing && _won != null;
    final isHiddenMine = revealAll && _mines.contains(index);

    Color bg = AppColors.surface.withValues(alpha: 0.9);
    Color border = Colors.white.withValues(alpha: 0.14);
    Widget content = Icon(
      Icons.lock_outline_rounded,
      color: Colors.white.withValues(alpha: 0.28),
      size: 24,
    );

    if (isSafeRevealed) {
      bg = AppColors.emerald.withValues(alpha: 0.24);
      border = AppColors.emerald;
      content = const Icon(
        Icons.diamond_rounded,
        color: AppColors.emerald,
        size: 32,
      );
    } else if (isExploded || isHiddenMine) {
      bg = AppColors.danger.withValues(alpha: isExploded ? 0.42 : 0.18);
      border = AppColors.danger;
      content = const Icon(
        Icons.dangerous_rounded,
        color: AppColors.danger,
        size: 30,
      );
    }

    return GestureDetector(
      onTap: () => _tapTile(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: isSafeRevealed || isExploded ? 2 : 1),
          boxShadow: isSafeRevealed
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Center(child: content),
      ),
    );
  }
}
