import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/performance_service.dart';

/// Kontrol katmanı yüzeyi: sheet ve diyaloglar için cam.
/// Metin yoğun olduğu için "regular" varyant: koyu tonlu yarı saydam dolgu, %35 koyu katman
/// ve arka planı bulanıklaştıran BackdropFilter. Performans modunda opak yüzeye düşer.
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
    final base = tint ?? const Color(0xFF1E293B);
    final content = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.72),
        borderRadius: borderRadius,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
      ),
      child: child,
    );

    if (PerformanceService.isPerformanceMode) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
            color: const Color(0xFF1E293B), padding: padding, child: child),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
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
