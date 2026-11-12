import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/token_economy.dart';
import '../services/token_arena_rules.dart';
import '../widgets/glass_container.dart';
import 'token_arena_hilo_screen.dart';
import 'token_arena_memory_screen.dart';
import 'token_arena_reflex_screen.dart';

/// Token Arena: jeton bahisli mini oyunların girişi.
class TokenArenaScreen extends StatelessWidget {
  const TokenArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payout = TokenArenaRules.payout(TokenEconomy.miniGameStake);
    final games = [
      _GameEntry(
        icon: Icons.swap_vert_rounded,
        color: const Color(0xFF6366F1),
        title: 'mg.higher_lower'.tr(),
        desc: 'mg.higher_lower_desc'.tr(),
        builder: (_) => const TokenArenaHiLoScreen(),
      ),
      _GameEntry(
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF10B981),
        title: 'mg.memory'.tr(),
        desc: 'mg.memory_desc'.tr(),
        builder: (_) => const TokenArenaMemoryScreen(),
      ),
      _GameEntry(
        icon: Icons.bolt_rounded,
        color: const Color(0xFFFF9F43),
        title: 'mg.reflex'.tr(),
        desc: 'mg.reflex_desc'.tr(),
        builder: (_) => const TokenArenaReflexScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('mg.title'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'mg.stake'.tr(args: ['${TokenEconomy.miniGameStake}', '$payout']),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          for (final g in games) ...[
            _buildCard(context, g),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _GameEntry g) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: g.builder)),
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        opacity: 0.1,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: g.color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(g.icon, color: g.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(g.desc, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _GameEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final WidgetBuilder builder;

  const _GameEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.builder,
  });
}
