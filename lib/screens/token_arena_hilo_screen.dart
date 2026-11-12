import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import 'token_arena_common.dart';

/// Yüksek-Düşük: arka arkaya [TokenArenaRules.hiLoRounds] doğru tahmin.
class TokenArenaHiLoScreen extends StatefulWidget {
  const TokenArenaHiLoScreen({super.key});

  @override
  State<TokenArenaHiLoScreen> createState() => _TokenArenaHiLoScreenState();
}

class _TokenArenaHiLoScreenState extends State<TokenArenaHiLoScreen> {
  static const _id = 'hilo';
  final Random _random = Random();

  bool _busy = false;
  bool _playing = false;
  int _round = 0;
  int _current = 1;
  int? _next;
  bool? _won;

  String _label(int v) {
    switch (v) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$v';
    }
  }

  Future<void> _start() async {
    if (_busy || _playing) return;
    setState(() => _busy = true);
    final ok = await arenaStake(context, _id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _playing = true;
        _round = 0;
        _current = TokenArenaRules.drawCard(_random);
        _next = null;
        _won = null;
      }
    });
  }

  void _guess(bool higher) {
    if (!_playing || _next != null) return;
    final next = TokenArenaRules.drawCard(_random);
    final correct = TokenArenaRules.hiLoGuessCorrect(
        current: _current, next: next, guessHigher: higher);
    setState(() => _next = next);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (!correct) {
        _finish(false);
        return;
      }
      final rounds = _round + 1;
      if (rounds >= TokenArenaRules.hiLoRounds) {
        _finish(true);
        return;
      }
      setState(() {
        _round = rounds;
        _current = next;
        _next = null;
      });
    });
  }

  Future<void> _finish(bool won) async {
    setState(() {
      _playing = false;
      _won = won;
    });
    await arenaFinish(_id, won);
  }

  Widget _card(String text, {bool hidden = false}) {
    return Container(
      width: 90,
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hidden ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        hidden ? '?' : text,
        style: TextStyle(
          color: hidden ? Colors.white54 : const Color(0xFF0F172A),
          fontSize: 40,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGuess = _playing && _next == null;
    return ArenaScaffold(
      title: 'mg.higher_lower'.tr(),
      child: Column(
        children: [
          Text(
            'mg.round'.tr(args: ['${_playing ? _round + 1 : 0}', '${TokenArenaRules.hiLoRounds}']),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _card(_label(_current)),
              const SizedBox(width: 24),
              _card(_next == null ? '' : _label(_next!), hidden: _next == null),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canGuess ? () => _guess(false) : null,
                  child: Text('mg.lower'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: canGuess ? () => _guess(true) : null,
                  child: Text('mg.higher'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_won != null) ...[
            ArenaResultBanner(won: _won!),
            const SizedBox(height: 14),
          ],
          ArenaPlayButton(
            label: _playing ? 'mg.your_turn'.tr() : 'mg.play'.tr(args: ['${TokenEconomy.miniGameStake}']),
            onPressed: _playing || _busy ? null : _start,
          ),
        ],
      ),
    );
  }
}
