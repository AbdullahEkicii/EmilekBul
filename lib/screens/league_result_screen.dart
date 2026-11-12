import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../services/league_service.dart';
import '../services/performance_service.dart';
import '../services/share_service.dart';
import 'league_screen.dart';
import 'package:emilekbul/services/haptic_service.dart';

/// Hafta sonu lig sonucu (terfi / düşme) tam ekranı.
/// Terfide hafif parçacık kutlaması (performans modunda kapalı), düşmede motive edici ton.
/// Üstteki kart PNG olarak paylaşılabilir.
class LeagueResultScreen extends StatefulWidget {
  final LeagueResult result;

  const LeagueResultScreen({super.key, required this.result});

  @override
  State<LeagueResultScreen> createState() => _LeagueResultScreenState();
}

class _LeagueResultScreenState extends State<LeagueResultScreen> with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  late final AnimationController _c;
  late final List<_Spark> _sparks;
  bool _sharing = false;

  bool get _promoted => widget.result.outcome == LeagueOutcome.promoted;
  bool get _lite => PerformanceService.isPerformanceMode;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _sparks = (_promoted && !_lite)
        ? List.generate(
            28,
            (_) => _Spark(
              x: rnd.nextDouble(),
              delay: rnd.nextDouble() * 0.4,
              speed: 0.5 + rnd.nextDouble() * 0.6,
              size: 3 + rnd.nextDouble() * 4,
            ),
          )
        : const [];
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
    if (_promoted) HapticService.heavy();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/league_result.png');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await ShareService.shareImageFile(
        context,
        path: file.path,
        text: 'league.share_text'.tr(args: [widget.result.to.titleKey.tr()]),
        contentType: 'league_result',
      );
    } catch (e) {
      debugPrint('League share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final accent = r.to.color;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          if (_sparks.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => CustomPaint(painter: _SparkPainter(_sparks, _c.value, accent)),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _c, curve: const Interval(0, 0.35, curve: Curves.easeOutBack)),
                    child: RepaintBoundary(key: _cardKey, child: _buildCard(r, accent)),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text('league.share'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('league.continue'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LeagueScreen()));
                    },
                    child: Text('league.view'.tr(), style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(LeagueResult r, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E293B), accent.withValues(alpha: 0.22)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(r.to.emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 10),
          Text(
            (_promoted ? 'league.promoted_title' : 'league.demoted_title').tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            r.to.titleKey.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text(
            (_promoted ? 'league.result_promoted_sub' : 'league.result_demoted_sub').tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14, height: 1.35),
          ),
          if (r.rank > 0) ...[
            const SizedBox(height: 14),
            _pill('league.result_rank'.tr(args: [r.rank.toString()]), accent),
          ],
          if (_promoted && r.reward > 0) ...[
            const SizedBox(height: 8),
            _pill('league.result_reward'.tr(args: [r.reward.toString()]), Colors.amberAccent),
          ],
          const SizedBox(height: 14),
          Text(
            'league.title'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class _Spark {
  final double x;
  final double delay;
  final double speed;
  final double size;

  const _Spark({required this.x, required this.delay, required this.speed, required this.size});
}

class _SparkPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double t;
  final Color color;

  _SparkPainter(this.sparks, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in sparks) {
      final p = ((t - s.delay) / 0.6 * s.speed).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      paint.color = color.withValues(alpha: (1 - p) * 0.9);
      final y = size.height * (0.75 - 0.6 * p);
      final x = size.width * s.x + sin(p * 6 + s.x * 10) * 12;
      canvas.drawCircle(Offset(x, y), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}
