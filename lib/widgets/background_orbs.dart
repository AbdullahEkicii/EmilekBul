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
            color.withOpacity(0.6),
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary prevents the animation from causing the whole screen to repaint
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: -50 + (30 * _orbAnimation.value),
                left: -50 + (20 * _orbAnimation.value),
                child: _buildOrb(250, const Color(0xFF667eea).withOpacity(0.3)),
              ),
              Positioned(
                bottom: 100 - (40 * _orbAnimation.value),
                right: -80 + (30 * _orbAnimation.value),
                child: _buildOrb(300, const Color(0xFF764ba2).withOpacity(0.2)),
              ),
              Positioned(
                top: 300 + (50 * (1 - _orbAnimation.value)),
                right: 100,
                child:
                    _buildOrb(150, const Color(0xFFA67BFF).withOpacity(0.15)),
              ),
            ],
          );
        },
      ),
    );
  }
}
