import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/performance_service.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final bool useBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.15,
    this.borderRadius = 24.0,
    this.padding,
    this.border,
    this.color,
    this.boxShadow,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveUseBlur = useBlur && !PerformanceService.isPerformanceMode;

    // In performance mode: use a solid opaque dark background instead of
    // near-transparent glass (which looks invisible without the blur effect).
    final Color baseColor = color ?? Colors.white;
    final Color bgColor = effectiveUseBlur
        ? baseColor.withValues(alpha: opacity)
        : (color != null
            ? color!.withValues(alpha: (opacity + 0.6).clamp(0.0, 1.0))
            : const Color(0xFF1E293B));

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveUseBlur ? null : bgColor,
        gradient: effectiveUseBlur
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color != null
                      ? color!.withValues(alpha: (opacity + 0.65).clamp(0.0, 1.0))
                      : const Color(0xFF1E293B),
                  color != null
                      ? color!.withValues(alpha: (opacity + 0.5).clamp(0.0, 1.0))
                      : const Color(0xFF0F172A),
                ],
              ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: effectiveUseBlur
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
        boxShadow: boxShadow ??
            (effectiveUseBlur
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]),
      ),
      child: effectiveUseBlur
          ? child
          : Material(
              color: Colors.transparent,
              child: child,
            ),
    );

    if (!effectiveUseBlur) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
            boxShadow: boxShadow,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
