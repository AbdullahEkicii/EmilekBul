import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Düello sonucunun paylaşılabilir görseli (PNG olarak yakalanır, bkz. ShareCardCapture).
class DuelShareCard extends StatelessWidget {
  final bool won;
  final String myName;
  final String myScore;
  final String oppName;
  final String oppScore;
  final String appTitle;

  const DuelShareCard({
    super.key,
    required this.won,
    required this.myName,
    required this.myScore,
    required this.oppName,
    required this.oppScore,
    required this.appTitle,
  });

  @override
  Widget build(BuildContext context) {
    final accent = won ? const Color(0xFFFFD56B) : const Color(0xFF818CF8);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'share.card_title'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2),
            ),
            Text(
              won ? 'share.card_win'.tr() : 'share.card_lose'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: accent, fontSize: 34, fontWeight: FontWeight.w900),
            ),
            Row(
              children: [
                Expanded(child: _side(myName, myScore, highlight: won)),
                Text(
                  'VS',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Expanded(child: _side(oppName, oppScore, highlight: !won)),
              ],
            ),
            Text(
              appTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _side(String name, String score, {required bool highlight}) {
    return Column(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          score,
          style: TextStyle(
            color: highlight ? const Color(0xFF34D399) : Colors.white70,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
