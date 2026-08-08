import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/token_service.dart';
import '../services/sound_service.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'glass_container.dart';

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
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    return lastSpin != todayStr;
  }

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSpinCompleted,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: LuckyWheelDialog(
                  onSpinCompleted: onSpinCompleted,
                ),
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final List<Map<String, dynamic>> _prizes = [
    {'amount': 30, 'label': '30 Token', 'color': Colors.purpleAccent},
    {'amount': 50, 'label': '50 Token', 'color': Colors.blueAccent},
    {'amount': 100, 'label': '100 Token', 'color': Colors.greenAccent},
    {'amount': 200, 'label': '200 Token', 'color': Colors.amberAccent},
    {'amount': 50, 'label': '50 Token', 'color': Colors.deepOrangeAccent},
    {'amount': 300, 'label': '300 Token! 🎉', 'color': Colors.pinkAccent},
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
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

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
    super.dispose();
  }

  void _spinWheel() async {
    if (_isSpinning || !_canSpin || _hasSpun) return;

    setState(() {
      _isSpinning = true;
    });

    final random = Random();
    _selectedPrizeIndex = random.nextInt(_prizes.length);

    final sectorAngle = (2 * pi) / _prizes.length;
    // Base angle to land exactly on the center of the chosen sector
    final targetSectorCenter = (2 * pi) - (_selectedPrizeIndex * sectorAngle);
    // Add a random offset within the sector so it feels realistic
    final randomOffset = (random.nextDouble() - 0.5) * (sectorAngle * 0.8);
    const fullRotations = 5; // Spin 5 times around
    _targetAngle = _startAngle + (fullRotations * 2 * pi) + targetSectorCenter + randomOffset;

    _animation = Tween<double>(begin: _startAngle, end: _targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    )..addListener(() {
        setState(() {});
      });

    SoundService.playCorrect();
    _controller.forward(from: 0.0).then((_) async {
      _startAngle = _targetAngle % (2 * pi);
      final prize = _prizes[_selectedPrizeIndex];
      final int amount = prize['amount'] as int;

      await TokenService.addTokens(amount);

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      await prefs.setString(LuckyWheelDialog._lastWheelSpinKey, todayStr);

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
    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎡', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Text(
                    'new_features.lucky_wheel'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasSpun
                ? 'new_features.wheel_won'.tr()
                : (_canSpin
                    ? 'new_features.wheel_spin_prompt'.tr()
                    : 'new_features.wheel_spun_today'.tr()),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Spinning Wheel Container
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Border
              Container(
                width: 296,
                height: 296,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.8), width: 8),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
                  ],
                ),
              ),
              // Wheel Canvas
              Transform.rotate(
                angle: _isSpinning || _hasSpun ? _animation.value : 0.0,
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: _WheelPainter(prizes: _prizes),
                  ),
                ),
              ),
              // Wheel Pointer at top
              Positioned(
                top: -8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.amberAccent, blurRadius: 12, spreadRadius: 2)
                    ],
                  ),
                  child: const Icon(Icons.arrow_drop_down, color: Colors.black, size: 32),
                ),
              ),
              // Center Cap
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade900,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amberAccent, width: 4),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2)
                  ],
                ),
                child: const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 28)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Spin Button
          if (_hasSpun) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Text(
                '${'new_features.wheel_you_won'.tr()} ${_prizes[_selectedPrizeIndex]['label']}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          ElevatedButton(
            onPressed: _isSpinning
                ? null
                : (_hasSpun
                    ? () => Navigator.of(context).pop()
                    : (_canSpin ? _spinWheel : null)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
            ),
            child: _isSpinning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : Text(
                    _hasSpun
                        ? 'new_features.wheel_awesome'.tr()
                        : (_canSpin ? 'new_features.wheel_spin_button'.tr() : 'new_features.wheel_done_today'.tr()),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> prizes;

  _WheelPainter({required this.prizes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * pi) / prizes.length;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * sweepAngle - (pi / 2) - (sweepAngle / 2);
      final prize = prizes[i];

      // Draw sector arc
      paint.color = (prize['color'] as Color).withValues(alpha: 0.9);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Add a subtle gradient overlay to make it look 3D and shiny
      final highlightPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.4), Colors.transparent],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        highlightPaint,
      );

      // Draw sector border lines
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw text
      final textAngle = startAngle + (sweepAngle / 2);
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + (pi / 2));

      final textSpan = TextSpan(
        text: prize['amount'].toString(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(1, 1))],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
