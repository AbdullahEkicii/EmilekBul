import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import 'token_arena_common.dart';

/// Hafıza dizisi: gösterilen renk dizisini aynı sırayla tekrarla. Tek hata kaybettirir.
class TokenArenaMemoryScreen extends StatefulWidget {
  const TokenArenaMemoryScreen({super.key});

  @override
  State<TokenArenaMemoryScreen> createState() => _TokenArenaMemoryScreenState();
}

class _TokenArenaMemoryScreenState extends State<TokenArenaMemoryScreen> {
  static const _id = 'memory';
  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFFACC15),
  ];

  final Random _random = Random();
  List<int> _sequence = const [];
  int _showIndex = -1; // -1: gösterim yok
  int _inputStep = 0;
  bool _showing = false;
  bool _playing = false;
  bool _busy = false;
  bool? _won;
  int _generation = 0; // eski zamanlayıcıları iptal etmek için

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || _playing || _showing) return;
    setState(() => _busy = true);
    final ok = await arenaStake(context, _id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    _sequence = TokenArenaRules.buildSequence(_random);
    setState(() {
      _won = null;
      _playing = true;
      _inputStep = 0;
    });
    _showSequence(++_generation);
  }

  Future<void> _showSequence(int gen) async {
    setState(() => _showing = true);
    for (var i = 0; i < _sequence.length; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted || gen != _generation) return;
      setState(() => _showIndex = i);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || gen != _generation) return;
      setState(() => _showIndex = -1);
    }
    if (!mounted || gen != _generation) return;
    setState(() => _showing = false);
  }

  void _tap(int color) {
    if (!_playing || _showing) return;
    if (!TokenArenaRules.memoryTapCorrect(_sequence, _inputStep, color)) {
      _finish(false);
      return;
    }
    final next = _inputStep + 1;
    if (next >= _sequence.length) {
      _finish(true);
    } else {
      setState(() => _inputStep = next);
    }
  }

  Future<void> _finish(bool won) async {
    _generation++;
    setState(() {
      _playing = false;
      _won = won;
      _showIndex = -1;
    });
    await arenaFinish(_id, won);
  }

  @override
  Widget build(BuildContext context) {
    final hint = _showing
        ? 'mg.watch'.tr()
        : _playing
            ? 'mg.your_turn'.tr()
            : 'mg.memory_desc'.tr();
    return ArenaScaffold(
      title: 'mg.memory'.tr(),
      child: Column(
        children: [
          Text(hint, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: [
                for (var c = 0; c < _colors.length; c++)
                  GestureDetector(
                    onTap: () => _tap(c),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _showIndex >= 0 && _sequence[_showIndex] == c ? 1 : 0.35,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _colors[c],
                          borderRadius: BorderRadius.circular(18),
                        ),
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
            label: _playing || _showing ? 'mg.your_turn'.tr() : 'mg.play'.tr(args: ['${TokenEconomy.miniGameStake}']),
            onPressed: _playing || _showing || _busy ? null : _start,
          ),
        ],
      ),
    );
  }
}
