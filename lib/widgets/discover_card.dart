import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../screens/daily_challenge_screen.dart';
import '../screens/league_screen.dart';
import '../screens/main_shell.dart';
import '../screens/shop_screen.dart';
import '../services/behavior_tracker.dart';
import '../services/nudge_engine.dart';
import 'friends_dialog.dart';
import 'lucky_wheel_dialog.dart';
import 'quick_match_dialog.dart';

/// Ana ekranda, oyuncunun henüz denemediği (ya da uzun süredir bırakmış olduğu) bir özelliği önerir.
/// Öneri gerçek davranış verisine dayanır; hiçbir şey denemiş değilse "önce bir tur" gösterir.
/// Kullanıcı kapatabilir; kapatma aynı gün için hatırlanır.
class DiscoverCard extends StatefulWidget {
  const DiscoverCard({super.key});

  @override
  State<DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<DiscoverCard> {
  String? _feature;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await BehaviorTracker.snapshot();
    // Önce hiç denenmemiş, yoksa bırakılmış bir özellik
    final candidates = [
      ...snap.neverUsed,
      ...snap.dormant(),
    ].where(NudgeEngine.discoverable.contains).toList();
    if (candidates.isEmpty) {
      if (mounted) setState(() => _feature = null);
      return;
    }
    if (!mounted) return;
    setState(() {
      _feature = candidates.first;
    });
  }

  void _open(BuildContext context) {
    switch (_feature) {
      case 'shop':
        if (!MainShell.selectTabOf(context, 3)) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
        }
        break;
      case 'league':
        if (!MainShell.selectTabOf(context, 2)) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LeagueScreen()));
        }
        break;
      case 'daily_challenge':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen()));
        break;
      case 'friends':
        FriendsDialog.show(context);
        break;
      case 'quick_match':
        QuickMatchDialog.show(context);
        break;
      case 'wheel':
        LuckyWheelDialog.show(context, onSpinCompleted: () {});
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    if (_dismissed || _feature == null) return const SizedBox.shrink();
    final label = 'nudge.feat_$_feature'.tr();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.explore_rounded, color: Color(0xFF7DD3FC), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('discover.title'.tr(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text('discover.body'.tr(args: [label]),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'discover.dismiss'.tr(),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
            onPressed: () => setState(() => _dismissed = true),
          ),
          Material(
            color: const Color(0xFF7DD3FC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _open(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('discover.cta'.tr(),
                    style: const TextStyle(
                        color: Color(0xFF0B1220), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
