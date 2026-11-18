import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import '../theme/app_theme.dart';
import 'token_arena_common.dart';

/// Çarpan Ruleti: 10 dilimli neon çark (0x / 0.5x / 1.5x / 3.5x, EV = 0.80).
class TokenArenaWheelScreen extends StatefulWidget {
  final int initialStake;

  const TokenArenaWheelScreen({
    super.key,
    this.initialStake = TokenEconomy.miniGameStake,
  });

  @override
  State<TokenArenaWheelScreen> createState() => _TokenArenaWheelScreenState();
}

class _TokenArenaWheelScreenState extends State<TokenArenaWheelScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late int _stake;
  int _balance = 0;

  late AnimationController _spinController;
  Animation<double> _angleAnim = const AlwaysStoppedAnimation(0.0);
  double _currentAngle = 0.0;
  bool _spinning = false;
  bool? _won;
  int? _lastSlot;
  int _payout = 0;

  @override
  void initState() {
    super.initState();
    _stake = widget.initialStake;
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _refreshBalance();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    final bal = await loadArenaBalance();
    if (mounted) setState(() => _balance = bal);
  }

  Future<void> _spin() async {
    if (_spinning) return;
    if (!await arenaStake(context, 'wheel', stake: _stake)) return;

    final slot = TokenArenaRules.spinWheelIndex(_rng);
    final sliceCount = TokenArenaRules.wheelMultipliers.length;
    final sliceAngle = (2 * pi) / sliceCount;

    // İşaretçi yukarıda (-pi/2); dilim merkezi tam işaretçinin altına gelecek şekilde hizala.
    final slotCenterOffset = (slot + 0.5) * sliceAngle;
    final fullSpins = (5 + _rng.nextInt(3)) * 2 * pi;
    final baseNormalized = _currentAngle % (2 * pi);
    final targetNormalized = (2 * pi) - slotCenterOffset;
    var delta = targetNormalized - baseNormalized;
    if (delta <= 0) delta += 2 * pi;
    final targetAngle = _currentAngle + fullSpins + delta;

    setState(() {
      _spinning = true;
      _won = null;
      _lastSlot = null;
      _payout = 0;
    });
    _refreshBalance();

    _angleAnim = Tween<double>(begin: _currentAngle, end: targetAngle).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    await _spinController.forward(from: 0);
    if (!mounted) return;
    _currentAngle = targetAngle;

    final mult = TokenArenaRules.wheelMultipliers[slot];
    final winAmount = TokenArenaRules.wheelPayout(_stake, slot);
    final isFullWin = mult >= 1.0;

    final paid = await arenaFinish(
      'wheel',
      isFullWin,
      stake: _stake,
      customPayout: winAmount,
    );
    if (!mounted) return;
    setState(() {
      _spinning = false;
      _won = isFullWin;
      _lastSlot = slot;
      _payout = paid;
    });
    _refreshBalance();
  }

  @override
  Widget build(BuildContext context) {
    final multText = _lastSlot != null
        ? '${TokenArenaRules.wheelMultipliers[_lastSlot!]}x'
        : '${TokenArenaRules.wheelMultipliers.reduce(max)}x';

    return ArenaScaffold(
      title: 'mg.wheel'.tr(),
      balance: _balance,
      accentColor: AppColors.gold,
      ruleSummary: 'mg.wheel_rule'.tr(),
      onBalanceTap: () => openTokenEarnScreen(context, onReturned: _refreshBalance),
      child: Column(
        children: [
          _buildLegend(),
          const Spacer(),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: AnimatedBuilder(
                  animation: _spinController,
                  builder: (_, __) {
                    return Transform.rotate(
                      angle: _angleAnim.value,
                      child: SizedBox(
                        width: 245,
                        height: 245,
                        child: CustomPaint(
                          painter: _NeonWheelPainter(
                            multipliers: TokenArenaRules.wheelMultipliers,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 46,
                color: AppColors.gold,
              ),
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.backgroundTop,
                        border: Border.all(color: AppColors.gold, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.4),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          multText,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_won != null) ...[
            ArenaResultBanner(
              won: _won!,
              stake: _stake,
              payoutAmount: _payout,
              currentBalance: _balance,
              onEarnTokens: () =>
                  openTokenEarnScreen(context, onReturned: _refreshBalance),
            ),
            const SizedBox(height: 12),
          ],
          if (!_spinning) ...[
            ArenaStakeSelector(
              selectedStake: _stake,
              previewMultiplier: 3.5,
              onSelected: (v) => setState(() => _stake = v),
              accentColor: AppColors.gold,
            ),
            const SizedBox(height: 12),
          ],
          ArenaPlayButton(
            label: _spinning
                ? 'mg.wheel_spinning'.tr()
                : 'mg.wheel_spin'.tr(args: ['$_stake']),
            onPressed: _spinning ? null : _spin,
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final items = <(String, Color)>[
      ('0x', AppColors.danger),
      ('0.5x', AppColors.amber),
      ('1.5x', AppColors.emerald),
      ('3.5x', AppColors.gold),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((e) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: e.$2.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: e.$2.withValues(alpha: 0.5)),
          ),
          child: Text(
            e.$1,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: e.$2,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NeonWheelPainter extends CustomPainter {
  final List<double> multipliers;

  const _NeonWheelPainter({required this.multipliers});

  Color _sliceColor(double m) {
    if (m >= 3.0) return AppColors.gold;
    if (m >= 1.5) return AppColors.emerald;
    if (m > 0) return AppColors.indigo;
    return const Color(0xFF273049);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = (2 * pi) / multipliers.length;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white24;

    for (var i = 0; i < multipliers.length; i++) {
      final startAngle = -pi / 2 + i * sliceAngle;
      final mult = multipliers[i];
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _sliceColor(mult);

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, startAngle, sliceAngle, true, paint);
      canvas.drawArc(rect, startAngle, sliceAngle, true, borderPaint);

      final label = mult == 0 ? '0x' : '${mult}x';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: mult >= 3.0 ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final midAngle = startAngle + sliceAngle / 2;
      final labelRadius = radius * 0.68;
      final offset = Offset(
        center.dx + cos(midAngle) * labelRadius - tp.width / 2,
        center.dy + sin(midAngle) * labelRadius - tp.height / 2,
      );
      tp.paint(canvas, offset);
    }

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = AppColors.gold.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _NeonWheelPainter oldDelegate) =>
      oldDelegate.multipliers != multipliers;
}
