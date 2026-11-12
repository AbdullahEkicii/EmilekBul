import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import '../services/token_service.dart';

/// Token Arena oyunlarının ortak iskeleti ve bahis akışı.
class ArenaScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const ArenaScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

/// Bahsi düşer. Yetersiz jetonda uyarı gösterip false döner.
Future<bool> arenaStake(BuildContext context, String gameId) async {
  final ok = await TokenService.stakeMiniGame(gameId);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('quiz.not_enough_tokens'.tr(args: ['${TokenEconomy.miniGameStake}'])),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  return ok;
}

/// Oyun sonucunu bildirir. Kazanılırsa geri ödeme yapılır.
Future<void> arenaFinish(String gameId, bool won) async {
  if (won) await TokenService.payMiniGame(gameId);
}

class ArenaPlayButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const ArenaPlayButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}

class ArenaResultBanner extends StatelessWidget {
  final bool won;

  const ArenaResultBanner({super.key, required this.won});

  @override
  Widget build(BuildContext context) {
    final payout = TokenArenaRules.payout(TokenEconomy.miniGameStake);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (won ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        won ? 'mg.win'.tr(args: ['$payout']) : 'mg.lose'.tr(args: ['${TokenEconomy.miniGameStake}']),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: won ? const Color(0xFF34D399) : const Color(0xFFF87171),
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}
