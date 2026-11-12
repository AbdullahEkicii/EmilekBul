import 'dart:math';

import 'package:flutter/material.dart';

/// Kusursuz test gibi özel anlar için ekranın üstünden dökülen kısa konfeti.
/// Etkileşimi engellemez (IgnorePointer) ve kendini kaldırır.
class ConfettiBurst {
  static OverlayEntry? _current;

  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _current?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiView(onDone: () {
        if (_current == entry) _current = null;
        entry.remove();
      }),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _Piece {
  final double x; // 0..1 ekran genişliği
  final double delay; // 0..0.4
  final double speed; // 0.6..1.1
  final double drift;
  final double size;
  final double spin;
  final Color color;
  const _Piece(this.x, this.delay, this.speed, this.drift, this.size, this.spin, this.color);
}

class _ConfettiView extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiView({required this.onDone});

  @override
  State<_ConfettiView> createState() => _ConfettiViewState();
}

class _ConfettiViewState extends State<_ConfettiView> with SingleTickerProviderStateMixin {
  static const _colors = [
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFF60A5FA),
    Color(0xFFF472B6),
    Color(0xFFA78BFA),
  ];

  late final AnimationController _c;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _pieces = List.generate(
      36,
      (_) => _Piece(
        rnd.nextDouble(),
        rnd.nextDouble() * 0.4,
        0.6 + rnd.nextDouble() * 0.5,
        (rnd.nextDouble() - 0.5) * 0.25,
        5 + rnd.nextDouble() * 5,
        (rnd.nextDouble() - 0.5) * 12,
        _colors[rnd.nextInt(_colors.length)],
      ),
    );
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            size: MediaQuery.sizeOf(context),
            painter: _ConfettiPainter(_pieces, _c.value),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = p.x * size.width + sin(local * 6 + p.spin) * 24 + p.drift * size.width * local;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
