import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/achievement_service.dart';
import '../services/performance_service.dart';

/// Başarım kilidi açıldığında üstte beliren hafif kutlama kartı.
/// Performans modunda konfeti/parıltı yok; sadece sade bir ölçek animasyonu.
class AchievementCelebration {
  static OverlayEntry? _current;

  static void show(BuildContext context, Achievement achievement) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _current?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationView(
        achievement: achievement,
        onDone: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _CelebrationView extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDone;

  const _CelebrationView({required this.achievement, required this.onDone});

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final bool _lite = PerformanceService.isPerformanceMode;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _particles = _lite
        ? const []
        : List.generate(
            16,
            (_) => _Particle(
              angle: rnd.nextDouble() * 2 * pi,
              speed: 60 + rnd.nextDouble() * 80,
              size: 3 + rnd.nextDouble() * 3,
              colorIndex: rnd.nextInt(3),
            ),
          );
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final top = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Giriş (0-0.12), bekleme, çıkış (0.88-1)
            final inT = Curves.easeOutBack.transform((t / 0.12).clamp(0.0, 1.0));
            final outT = ((t - 0.88) / 0.12).clamp(0.0, 1.0);
            final opacity = (1 - outT).clamp(0.0, 1.0);
            final scale = (0.7 + 0.3 * inT) * (1 - 0.05 * outT);
            final burstT = ((t - 0.08) / 0.4).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (!_lite && burstT > 0 && burstT < 1)
                      Positioned(
                        left: 40,
                        top: 30,
                        child: CustomPaint(
                          size: const Size(1, 1),
                          painter: _ConfettiPainter(_particles, burstT, a.color),
                        ),
                      ),
                    Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: a.color.withValues(alpha: 0.7), width: 1.5),
                          boxShadow: _lite
                              ? null
                              : [
                                  BoxShadow(
                                    color: a.color.withValues(alpha: 0.25 + 0.2 * sin(t * 2 * pi * 2).abs()),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: a.color.withValues(alpha: 0.18),
                              ),
                              child: Icon(a.icon, color: a.color, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'achievements.unlocked_toast'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                  Text(
                                    a.titleKey.tr(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final int colorIndex;

  const _Particle({required this.angle, required this.speed, required this.size, required this.colorIndex});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final Color base;

  _ConfettiPainter(this.particles, this.t, this.base);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [base, Colors.amberAccent, Colors.white];
    final paint = Paint();
    for (final p in particles) {
      final dist = p.speed * Curves.easeOut.transform(t);
      final dx = cos(p.angle) * dist;
      final dy = sin(p.angle) * dist + 30 * t * t;
      paint.color = colors[p.colorIndex].withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
