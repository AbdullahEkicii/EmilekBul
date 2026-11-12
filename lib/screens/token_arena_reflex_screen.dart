import 'dart:async';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import 'token_arena_common.dart';

/// Refleks: yanan hedefe hızlıca dokun. [TokenArenaRules.reflexHitsNeeded] isabet yeterli.
class TokenArenaReflexScreen extends StatefulWidget {
  const TokenArenaReflexScreen({super.key});

  @override
  State<TokenArenaReflexScreen> createState() => _TokenArenaReflexScreenState();
}

class _TokenArenaReflexScreenState extends State<TokenArenaReflexScreen> {
  static const _id = 'reflex';
  // Hedef yanma süresi: oyun ilerledikçe kısalır (zorluk artışı)
  static const _baseWindowMs = 900;
  static const _minWindowMs = 450;

  final Random _random = Random();
  Timer? _spawnTimer;
  Timer? _expireTimer;
  int _lit = -1;
  int _hits = 0;
  int _misses = 0;
  bool _playing = false;
  bool _busy = false;
  bool? _won;

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _expireTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || _playing) return;
    setState(() => _busy = true);
    final ok = await arenaStake(context, _id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    setState(() {
      _playing = true;
      _won = null;
      _hits = 0;
      _misses = 0;
      _lit = -1;
    });
    _scheduleSpawn();
  }

  int get _windowMs {
    final ms = _baseWindowMs - _hits * 60;
    return ms < _minWindowMs ? _minWindowMs : ms;
  }

  void _scheduleSpawn() {
    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: 350 + _random.nextInt(450)), _spawn);
  }

  void _spawn() {
    if (!mounted || !_playing) return;
    setState(() => _lit = _random.nextInt(TokenArenaRules.reflexTiles));
    _expireTimer?.cancel();
    _expireTimer = Timer(Duration(milliseconds: _windowMs), () {
      if (!mounted || !_playing) return;
      _registerMiss();
    });
  }

  void _tap(int tile) {
    if (!_playing) return;
    if (tile == _lit) {
      _expireTimer?.cancel();
      setState(() {
        _lit = -1;
        _hits++;
      });
      if (TokenArenaRules.reflexWon(_hits)) {
        _finish(true);
      } else {
        _scheduleSpawn();
      }
    } else {
      _registerMiss();
    }
  }

  void _registerMiss() {
    _expireTimer?.cancel();
    setState(() {
      _lit = -1;
      _misses++;
    });
    if (TokenArenaRules.reflexLost(_misses)) {
      _finish(false);
    } else {
      _scheduleSpawn();
    }
  }

  Future<void> _finish(bool won) async {
    _spawnTimer?.cancel();
    _expireTimer?.cancel();
    setState(() {
      _playing = false;
      _won = won;
      _lit = -1;
    });
    await arenaFinish(_id, won);
  }

  @override
  Widget build(BuildContext context) {
    return ArenaScaffold(
      title: 'mg.reflex'.tr(),
      child: Column(
        children: [
          Text(
            'mg.round'.tr(args: ['$_hits', '${TokenArenaRules.reflexHitsNeeded}']),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var t = 0; t < TokenArenaRules.reflexTiles; t++)
                  GestureDetector(
                    onTap: () => _tap(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: t == _lit ? const Color(0xFFFF9F43) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_won != null) ...[
            ArenaResultBanner(won: _won!),
            const SizedBox(height: 14),
          ],
          ArenaPlayButton(
            label: _playing
                ? 'mg.your_turn'.tr()
                : 'mg.play'.tr(args: ['${TokenEconomy.miniGameStake}']),
            onPressed: _playing || _busy ? null : _start,
          ),
        ],
      ),
    );
  }
}
