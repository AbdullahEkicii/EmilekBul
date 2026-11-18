import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/performance_service.dart';
import '../theme/app_theme.dart';

/// Kontrol katmanı yüzeyi: sheet ve diyaloglar için ferah cam katmanı.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final Color? tint;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.height,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final base = tint ?? AppColors.surfaceElevated;
    final content = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.64),
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.9,
        ),
      ),
      child: child,
    );

    if (PerformanceService.isPerformanceMode) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          color: base,
          padding: padding,
          child: child,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.backgroundTop.withValues(alpha: 0.28),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: content,
          ),
        ],
      ),
    );
  }
}
