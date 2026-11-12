import 'package:flutter/material.dart';
import 'glass_surface.dart';

/// AlertDialog'un cam sürümü. Aynı adlandırılmış parametreleri kabul eder
/// (title, content, actions, backgroundColor, shape, actionsAlignment).
/// Yüzey kontrol katmanı camıdır; metin yoğun olduğu için regular varyant kullanılır.
class GlassAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final MainAxisAlignment? actionsAlignment;

  const GlassAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
    this.shape,
    this.actionsAlignment,
  });

  static const _defaultRadius = BorderRadius.all(Radius.circular(24));

  BorderRadius get _radius {
    final s = shape;
    if (s is RoundedRectangleBorder) {
      return s.borderRadius.resolve(TextDirection.ltr);
    }
    return _defaultRadius;
  }

  static WrapAlignment _wrapAlignment(MainAxisAlignment? a) {
    switch (a) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return WrapAlignment.spaceEvenly;
      case MainAxisAlignment.end:
      case null:
        return WrapAlignment.end;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassSurface(
        borderRadius: _radius,
        tint: backgroundColor,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) title!,
            if (content != null) ...[
              if (title != null) const SizedBox(height: 16),
              content!,
            ],
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: _wrapAlignment(actionsAlignment),
                spacing: 8,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
