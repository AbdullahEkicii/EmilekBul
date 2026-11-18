import 'dart:async';
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

/// Refleks Vuruşu: 7 hedefi yakala, kırmızı tuzak bombalarına basma (1.8x ödeme).
class TokenArenaReflexScreen extends StatefulWidget {
  final int initialStake;

  const TokenArenaReflexScreen({
    super.key,
    this.initialStake = TokenEconomy.miniGameStake,
  });

  @override
  State<TokenArenaReflexScreen> createState() => _TokenArenaReflexScreenState();
}

class _TokenArenaReflexScreenState extends State<TokenArenaReflexScreen> {
  final _rng = Random();
  late int _stake;
  int _balance = 0;

  Timer? _timer;
  int? _active;
  bool _isTrap = false;
  bool _playing = false;
  bool? _won;
  int _payout = 0;
  int _hits = 0;
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    _stake = widget.initialStake;
    _refreshBalance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    final bal = await loadArenaBalance();
    if (mounted) setState(() => _balance = bal);
  }

  Future<void> _start() async {
    if (!await arenaStake(context, 'reflex', stake: _stake)) return;
    _timer?.cancel();
    setState(() {
      _playing = true;
      _won = null;
      _payout = 0;
      _hits = 0;
      _misses = 0;
      _active = null;
      _isTrap = false;
    });
    _refreshBalance();
    _spawnNext();
  }

  void _spawnNext() {
    _timer?.cancel();
    if (!mounted || !_playing) return;
    final spawnTrap = _rng.nextInt(4) == 0; // %25 tuzak bomba olasılığı
    final windowMs = TokenArenaRules.reflexWindowMs(_hits);
    setState(() {
      _active = _rng.nextInt(TokenArenaRules.reflexTiles);
      _isTrap = spawnTrap;
    });
    _timer = Timer(Duration(milliseconds: windowMs), () {
      if (!mounted || !_playing) return;
      if (_isTrap) {
        // Tuzağa dokunmamak başarılı kaçınma sayılır; sıradaki hedefi çıkar.
        _spawnNext();
        return;
      }
      _registerMiss();
    });
  }

  void _registerMiss() {
    _misses++;
    HapticService.wrong();
    if (TokenArenaRules.reflexLost(_misses)) {
      _finish(false);
    } else {
      SoundService.playWrong();
      _spawnNext();
    }
  }

  Future<void> _tap(int idx) async {
    if (!_playing) return;
    if (idx == _active) {
      _timer?.cancel();
      if (_isTrap) {
        _registerMiss();
        return;
      }
      _hits++;
      SoundService.playCorrect();
      HapticService.light();
      if (TokenArenaRules.reflexWon(_hits)) {
        await _finish(true);
      } else {
        _spawnNext();
      }
    } else {
      // Boş kareye hatalı dokunuş da can götürür.
      _timer?.cancel();
      _registerMiss();
    }
  }

  Future<void> _finish(bool won) async {
    _timer?.cancel();
    final paid = await arenaFinish('reflex', won, stake: _stake);
    if (!mounted) return;
    setState(() {
      _playing = false;
      _active = null;
      _isTrap = false;
      _won = won;
      _payout = paid;
    });
    _refreshBalance();
  }

  @override
  Widget build(BuildContext context) {
    final totalLives = TokenArenaRules.reflexMaxMisses + 1;
    final livesLeft = (totalLives - _misses).clamp(0, totalLives);

    return ArenaScaffold(
      title: 'mg.reflex'.tr(),
      balance: _balance,
      accentColor: AppColors.amber,
      ruleSummary: 'mg.reflex_rule'.tr(),
      onBalanceTap: () => openTokenEarnScreen(context, onReturned: _refreshBalance),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'mg.round'.tr(args: [
                        '$_hits',
                        '${TokenArenaRules.reflexHitsNeeded}',
                      ]),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: List.generate(totalLives, (i) {
                        final alive = i < livesLeft;
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            alive
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: alive ? AppColors.danger : Colors.white24,
                            size: 20,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _hits / TokenArenaRules.reflexHitsNeeded,
                    minHeight: 7,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(AppColors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: List.generate(TokenArenaRules.reflexTiles, (i) {
                final on = _active == i;
                final isBomb = on && _isTrap;
                final tileColor =
                    isBomb ? AppColors.danger : AppColors.amber;
                return GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    decoration: BoxDecoration(
                      color: on
                          ? tileColor
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: on
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.12),
                        width: on ? 2.5 : 1,
                      ),
                      boxShadow: on
                          ? [
                              BoxShadow(
                                color: tileColor.withValues(alpha: 0.65),
                                blurRadius: 22,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: on
                          ? Icon(
                              isBomb
                                  ? Icons.dangerous_rounded
                                  : Icons.bolt_rounded,
                              color: isBomb ? Colors.white : Colors.black87,
                              size: 42,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              color: Colors.white.withValues(alpha: 0.14),
                              size: 22,
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
              accentColor: AppColors.amber,
            ),
            const SizedBox(height: 12),
            ArenaPlayButton(
              label: 'mg.play'.tr(args: ['$_stake']),
              onPressed: _start,
              color: AppColors.amber,
            ),
          ],
        ],
      ),
    );
  }
}
