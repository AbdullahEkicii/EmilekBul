import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/performance_service.dart';
import '../theme/app_theme.dart';

/// Ferah, ışık yakalayan buzlu yüzey malzemesi.
/// Varsayılan: ince speküler kenarlı, nefes alan safir-cam görünüm (ağırlık yapan siyah gölge yok).
/// Kontrol katmanlarında `useBlur: true` ile gerçek arka plan bulanıklığı sağlar.
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
  final bool scrim;

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
    this.useBlur = false,
    this.scrim = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveUseBlur =
        useBlur && !PerformanceService.isPerformanceMode;

    final Color baseColor = color ?? Colors.white;
    final List<Color> lightFrostedGradient = color != null
        ? [
            color!.withValues(alpha: (opacity + 0.58).clamp(0.0, 1.0)),
            color!.withValues(alpha: (opacity + 0.42).clamp(0.0, 1.0)),
          ]
        : [
            AppColors.surfaceElevated.withValues(alpha: 0.78),
            AppColors.surface.withValues(alpha: 0.72),
          ];

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: effectiveUseBlur
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: lightFrostedGradient,
              ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: effectiveUseBlur ? 0.24 : 0.16),
              width: 1,
            ),
        boxShadow: boxShadow ??
            (effectiveUseBlur
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0A192F).withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
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
      child: Stack(
        children: [
          if (scrim)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.backgroundTop.withValues(alpha: 0.36),
              ),
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withValues(alpha: (opacity + 0.08).clamp(0.0, 1.0)),
                    baseColor.withValues(alpha: (opacity * 0.55).clamp(0.0, 1.0)),
                  ],
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: border ??
                    Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                      width: 0.9,
                    ),
                boxShadow: boxShadow ??
                    [
                      BoxShadow(
                        color: const Color(0xFF09162B).withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
              ),
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
