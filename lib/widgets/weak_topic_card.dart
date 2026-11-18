import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../constants/app_categories.dart';
import '../services/adaptive_service.dart';

/// Kategori ekranında, yeterli cevap verilmişse en zayıf konuyu gösteren kart.
/// Zorluk, Elo beceri puanına göre önerilir; tıklanınca o kategoride test başlar.
class WeakTopicCard extends StatefulWidget {
  final void Function(String category, String difficulty, int duration) onStart;

  const WeakTopicCard({super.key, required this.onStart});

  @override
  State<WeakTopicCard> createState() => _WeakTopicCardState();
}

class _WeakTopicCardState extends State<WeakTopicCard> {
  MasteryInfo? _weak;
  String _difficulty = 'Orta';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final weak = await AdaptiveService.weakestTopic();
    if (weak == null) {
      if (mounted) setState(() => _weak = null);
      return;
    }
    final diff = await AdaptiveService.recommendedDifficulty(weak.category);
    if (!mounted) return;
    setState(() {
      _weak = weak;
      _difficulty = diff;
    });
  }

  int _duration(String difficulty) {
    switch (difficulty) {
      case 'Kolay':
        return 15;
      case 'Zor':
        return 30;
      default:
        return 25;
    }
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    final weak = _weak;
    if (weak == null) return const SizedBox.shrink();
    final pct = (weak.accuracy * 100).round();
    final catKey = AppCategories.getCategoryKey(weak.category);
    final localizedCat = catKey.isNotEmpty ? catKey.tr() : weak.category;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [
          const Color(0xFF0EA5E9).withValues(alpha: 0.28),
          const Color(0xFF6366F1).withValues(alpha: 0.22),
        ]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF7DD3FC), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('adaptive.weak_title'.tr(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  'adaptive.weak_body'.tr(args: [localizedCat, '$pct', '${weak.level}']),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF7DD3FC),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => widget.onStart(weak.category, _difficulty, _duration(_difficulty)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text('adaptive.weak_cta'.tr(),
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
