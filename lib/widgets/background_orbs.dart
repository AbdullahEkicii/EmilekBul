import 'package:flutter/material.dart';
import '../services/performance_service.dart';

class BackgroundOrbs extends StatefulWidget {
  const BackgroundOrbs({super.key});

  @override
  State<BackgroundOrbs> createState() => _BackgroundOrbsState();
}

class _BackgroundOrbsState extends State<BackgroundOrbs>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    if (!PerformanceService.isPerformanceMode) {
      _orbController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.65),
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 0.85],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ferah gökyüzü-aurora ışık geçişleri: çamur moru yerine nefes alan turkuaz, nane ve gün ışığı.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: -80 + (28 * _orbAnimation.value),
                right: -60 + (20 * _orbAnimation.value),
                child: _buildOrb(320, const Color(0xFF38BDF8).withValues(alpha: 0.24)),
              ),
              Positioned(
                top: 180 + (40 * (1 - _orbAnimation.value)),
                left: -90 + (25 * _orbAnimation.value),
                child: _buildOrb(260, const Color(0xFF34D399).withValues(alpha: 0.16)),
              ),
              Positioned(
                bottom: 70 - (36 * _orbAnimation.value),
                right: -40 + (24 * _orbAnimation.value),
                child: _buildOrb(290, const Color(0xFFFBBF24).withValues(alpha: 0.13)),
              ),
              Positioned(
                bottom: -70 + (22 * _orbAnimation.value),
                left: 40,
                child: _buildOrb(220, const Color(0xFF7DD3FC).withValues(alpha: 0.14)),
              ),
            ],
          );
        },
      ),
    );
  }
}
