import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/token_service.dart';
import '../services/sound_service.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;

class LuckyWheelDialog extends StatefulWidget {
  final VoidCallback onSpinCompleted;

  const LuckyWheelDialog({
    super.key,
    required this.onSpinCompleted,
  });

  static const String _lastWheelSpinKey = 'last_wheel_spin_date';

  static Future<bool> canSpinToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpin = prefs.getString(_lastWheelSpinKey);
    if (lastSpin == null) return true;

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    return lastSpin != todayStr;
  }

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSpinCompleted,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LuckyWheel',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: LuckyWheelDialog(
                onSpinCompleted: onSpinCompleted,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<LuckyWheelDialog> createState() => _LuckyWheelDialogState();
}

class _LuckyWheelDialogState extends State<LuckyWheelDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController _bulbController;
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;
  late ValueNotifier<double> _pointerTickNotifier;
  late ValueNotifier<double> _currentRotationNotifier;

  final List<Map<String, dynamic>> _prizes = [
    {'amount': 30, 'label': '30 Token', 'color': const Color(0xFF8B5CF6)},
    {'amount': 50, 'label': '50 Token', 'color': const Color(0xFF3B82F6)},
    {'amount': 100, 'label': '100 Token', 'color': const Color(0xFF10B981)},
    {'amount': 250, 'label': '250 Token! 🔥', 'color': const Color(0xFFF59E0B)},
    {'amount': 40, 'label': '40 Token', 'color': const Color(0xFFEC4899)},
    {'amount': 75, 'label': '75 Token', 'color': const Color(0xFF06B6D4)},
    {'amount': 500, 'label': '500 JACKPOT! 🏆', 'color': const Color(0xFFEF4444)},
    {'amount': 60, 'label': '60 Token', 'color': const Color(0xFF14B8A6)},
  ];

  bool _isSpinning = false;
  bool _hasSpun = false;
  int _selectedPrizeIndex = 0;
  double _startAngle = 0.0;
  double _targetAngle = 0.0;
  bool _canSpin = true;

  @override
  void initState() {
    super.initState();
    _pointerTickNotifier = ValueNotifier<double>(0.0);
    _currentRotationNotifier = ValueNotifier<double>(0.0);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 4500),
      vsync: this,
    );

    _bulbController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _confettiAnimation = CurvedAnimation(parent: _confettiController, curve: Curves.easeOut);

    _checkSpinAvailability();
  }

  Future<void> _checkSpinAvailability() async {
    final available = await LuckyWheelDialog.canSpinToday();
    if (mounted) {
      setState(() {
        _canSpin = available;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _bulbController.dispose();
    _confettiController.dispose();
    _pointerTickNotifier.dispose();
    _currentRotationNotifier.dispose();
    super.dispose();
  }

  void _spinWheel() async {
    if (_isSpinning || !_canSpin || _hasSpun) return;

    setState(() {
      _isSpinning = true;
    });

    final random = Random();
    // Probabilistic / weighted selection or random
    _selectedPrizeIndex = random.nextInt(_prizes.length);

    final sectorAngle = (2 * pi) / _prizes.length;
    // Target center angle so pointer (top) lands right on the selected sector
    final targetSectorCenter = (2 * pi) - (_selectedPrizeIndex * sectorAngle);
    // Subtle realistic random offset within sector
    final randomOffset = (random.nextDouble() - 0.5) * (sectorAngle * 0.6);
    const fullRotations = 6; // 6 dramatic rotations
    _targetAngle = _startAngle + (fullRotations * 2 * pi) + targetSectorCenter + randomOffset;

    _animation = Tween<double>(begin: _startAngle, end: _targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        final currentRotation = _animation.value;
        _currentRotationNotifier.value = currentRotation;
        final tickFraction = (currentRotation * _prizes.length / (2 * pi)) % 1.0;
        _pointerTickNotifier.value = tickFraction < 0.15 ? -0.15 : 0.0;
      });

    SoundService.playCorrect();

    _controller.forward(from: 0.0).then((_) async {
      _startAngle = _targetAngle % (2 * pi);
      _currentRotationNotifier.value = _startAngle;
      final prize = _prizes[_selectedPrizeIndex];
      final int amount = prize['amount'] as int;

      await TokenService.addTokens(amount);

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      await prefs.setString(LuckyWheelDialog._lastWheelSpinKey, todayStr);

      _confettiController.forward(from: 0.0);

      if (mounted) {
        setState(() {
          _isSpinning = false;
          _hasSpun = true;
          _canSpin = false;
        });
        widget.onSpinCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: const Color(0xFF131127).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9F43).withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background Orbs
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withValues(alpha: 0.25),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title & Close Button Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD56B), Color(0xFFFF9F43)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF9F43).withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Text('🎡', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'new_features.lucky_wheel'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _hasSpun
                                  ? 'new_features.wheel_won'.tr()
                                  : (_canSpin
                                      ? 'new_features.wheel_spin_prompt'.tr()
                                      : 'new_features.wheel_spun_today'.tr()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // The Grand Lucky Wheel
                  _buildWheelWidget(),
                  const SizedBox(height: 24),

                  // Celebration Banner or Reward Status
                  if (_hasSpun) ...[
                    FadeTransition(
                      opacity: _confettiAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withValues(alpha: 0.25),
                              const Color(0xFF059669).withValues(alpha: 0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF34D399), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFFFFD56B), size: 24),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${'new_features.wheel_you_won'.tr()} ${_prizes[_selectedPrizeIndex]['label']}',
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action Spin Button
                  _buildSpinButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelWidget() {
    const double wheelSize = 280;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 1. Outer Glow Aura
        Container(
          width: wheelSize + 30,
          height: wheelSize + 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9F43).withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                blurRadius: 60,
                spreadRadius: 5,
              ),
            ],
          ),
        ),

        // 2. Carnival Studded Outer Frame
        AnimatedBuilder(
          animation: _bulbController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(wheelSize + 26, wheelSize + 26),
              painter: _CarnivalRimPainter(
                bulbPhase: _bulbController.value,
                prizesCount: _prizes.length,
              ),
            );
          },
        ),

        // 3. Rotating Wheel Canvas (RepaintBoundary ensures cached GPU texture)
        ValueListenableBuilder<double>(
          valueListenable: _currentRotationNotifier,
          builder: (context, rotation, child) {
            return Transform.rotate(
              angle: rotation,
              child: child,
            );
          },
          child: RepaintBoundary(
            child: SizedBox(
              width: wheelSize,
              height: wheelSize,
              child: CustomPaint(
                painter: _LuxuryWheelPainter(prizes: _prizes),
              ),
            ),
          ),
        ),

        // 4. Center Gold Hub & Trophy Icon
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFFAEB), Color(0xFFFFD56B), Color(0xFFD97706), Color(0xFF78350F)],
              stops: [0.0, 0.45, 0.8, 1.0],
            ),
            border: Border.all(color: const Color(0xFFFFFAEB), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFFFFD56B).withValues(alpha: 0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.stars_rounded,
              color: Color(0xFF78350F),
              size: 32,
            ),
          ),
        ),

        // 5. Deluxe 3D Pointer / Needle (At Top)
        Positioned(
          top: -14,
          child: ValueListenableBuilder<double>(
            valueListenable: _pointerTickNotifier,
            builder: (context, tick, child) {
              return Transform.rotate(
                angle: tick,
                alignment: Alignment.topCenter,
                child: child,
              );
            },
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(36, 42),
                painter: _PointerNeedlePainter(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpinButton() {
    final bool isReadyToSpin = _canSpin && !_hasSpun && !_isSpinning;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSpinning
            ? null
            : (_hasSpun
                ? () => Navigator.of(context).pop()
                : (_canSpin ? _spinWheel : null)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isReadyToSpin
              ? const Color(0xFFFF9F43)
              : (_hasSpun ? const Color(0xFF10B981) : Colors.white12),
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: isReadyToSpin ? 8 : 0,
          shadowColor: const Color(0xFFFF9F43).withValues(alpha: 0.6),
        ),
        child: _isSpinning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _hasSpun
                        ? Icons.check_circle_rounded
                        : (_canSpin ? Icons.play_arrow_rounded : Icons.lock_clock_rounded),
                    color: isReadyToSpin || _hasSpun ? Colors.black : Colors.white38,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _hasSpun
                        ? 'new_features.wheel_awesome'.tr()
                        : (_canSpin
                            ? 'new_features.wheel_spin_button'.tr()
                            : 'new_features.wheel_done_today'.tr()),
                    style: TextStyle(
                      color: isReadyToSpin || _hasSpun ? Colors.black : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Renders the carnival-style gold rim with pulsating illuminated bulbs
class _CarnivalRimPainter extends CustomPainter {
  final double bulbPhase;
  final int prizesCount;

  _CarnivalRimPainter({required this.bulbPhase, required this.prizesCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Metallic Gold Outer Rim
    final goldRimPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFD97706),
          Color(0xFFFFE082),
          Color(0xFF92400E),
          Color(0xFFFFFAEB),
          Color(0xFFD97706),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    canvas.drawCircle(center, radius - 7, goldRimPaint);

    // Inner Dark Lip
    final lipPaint = Paint()
      ..color = const Color(0xFF1E1B4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 14, lipPaint);

    // Illuminated Bulbs
    final int totalBulbs = prizesCount * 3;
    final bulbRadius = radius - 7;

    for (int i = 0; i < totalBulbs; i++) {
      final angle = (2 * pi / totalBulbs) * i;
      final bulbX = center.dx + bulbRadius * cos(angle);
      final bulbY = center.dy + bulbRadius * sin(angle);
      final isLit = (i % 2 == 0) ? (bulbPhase > 0.5) : (bulbPhase <= 0.5);

      final bulbPaint = Paint()
        ..color = isLit ? const Color(0xFFFFF7ED) : const Color(0xFF78350F)
        ..style = PaintingStyle.fill;

      if (isLit) {
        final glowPaint = Paint()
          ..color = const Color(0xFFFFD56B).withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(bulbX, bulbY), 3.5, glowPaint);
      }

      canvas.drawCircle(Offset(bulbX, bulbY), 2.2, bulbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CarnivalRimPainter oldDelegate) =>
      oldDelegate.bulbPhase != bulbPhase;
}

/// Renders the rich gradient wheel sectors with 3D bevels, golden spokes, and icons
class _LuxuryWheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> prizes;

  _LuxuryWheelPainter({required this.prizes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * pi) / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * sweepAngle - (pi / 2) - (sweepAngle / 2);
      final prize = prizes[i];
      final baseColor = prize['color'] as Color;

      // 1. Sector Gradient (Rich Vibrant Base)
      final sectorPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.95),
            HSLColor.fromColor(baseColor).withLightness(0.28).toColor(),
          ],
          stops: const [0.2, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        sectorPaint,
      );

      // 2. Glossy Highlight Reflection (Top Arcs)
      final glossPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        glossPaint,
      );

      // 3. Golden Divider Spoke Lines
      final spokePaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFAEB), Color(0xFFFFD56B), Color(0xFFD97706)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        spokePaint,
      );

      // 4. Sector Content: Amount & Coin Icon
      final textAngle = startAngle + (sweepAngle / 2);
      final textRadius = radius * 0.62;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + (pi / 2));

      // Amount Number
      final textSpan = TextSpan(
        text: '${prize['amount']}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 17,
          letterSpacing: 0.5,
          shadows: [
            Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(1, 2)),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2 - 8),
      );

      // "TOKEN" subtitle
      const subSpan = TextSpan(
        text: '🪙 TOKEN',
        style: TextStyle(
          color: Color(0xFFFFD56B),
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.8,
          shadows: [
            Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      );
      final subPainter = TextPainter(
        text: subSpan,
        textDirection: TextDirection.ltr,
      );
      subPainter.layout();
      subPainter.paint(
        canvas,
        Offset(-subPainter.width / 2, textPainter.height / 2 - 6),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders a sharp 3D Golden pointer/needle with a ruby jewel center
class _PointerNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Outer Shadow
    final shadowPath = Path()
      ..moveTo(width / 2, height)
      ..lineTo(0, height * 0.25)
      ..quadraticBezierTo(width / 2, -4, width, height * 0.25)
      ..close();

    canvas.drawShadow(shadowPath, const Color(0xCC000000), 8, true);

    // Golden Body
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFAEB), Color(0xFFFFD56B), Color(0xFFF59E0B), Color(0xFF78350F)],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(shadowPath, bodyPaint);

    // Bevel Edge Line
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(shadowPath, bevelPaint);

    // Ruby Center Jewel
    final jewelPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFF6B6B), Color(0xFFDC2626), Color(0xFF7F1D1D)],
      ).createShader(Rect.fromCircle(center: Offset(width / 2, height * 0.35), radius: 6));

    canvas.drawCircle(Offset(width / 2, height * 0.35), 6, jewelPaint);
    canvas.drawCircle(
      Offset(width / 2, height * 0.35),
      6,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
