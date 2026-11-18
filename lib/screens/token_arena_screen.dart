import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/haptic_service.dart';
import '../services/token_arena_rules.dart';
import '../services/token_economy.dart';
import '../theme/app_theme.dart';
import '../widgets/my_native_ad.dart';
import 'token_arena_common.dart';
import 'token_arena_hilo_screen.dart';
import 'token_arena_memory_screen.dart';
import 'token_arena_mines_screen.dart';
import 'token_arena_reflex_screen.dart';
import 'token_arena_wheel_screen.dart';

/// Token Arena: 5 farklı yetenek & şans mini oyunuyla jeton bahsi hub ekranı.
class TokenArenaScreen extends StatefulWidget {
  const TokenArenaScreen({super.key});

  @override
  State<TokenArenaScreen> createState() => _TokenArenaScreenState();
}

class _TokenArenaScreenState extends State<TokenArenaScreen> {
  int _selectedStake = TokenEconomy.miniGameStake;
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final bal = await loadArenaBalance();
    if (mounted) setState(() => _balance = bal);
  }

  void _openGame(Widget Function(int stake) builder) {
    HapticService.selection();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => builder(_selectedStake)))
        .then((_) => _refreshBalance());
  }

  @override
  Widget build(BuildContext context) {
    final lowBalance = _balance < _selectedStake;

    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'mg.title'.tr(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: ArenaBalancePill(
                balance: _balance,
                onTap: () =>
                    openTokenEarnScreen(context, onReturned: _refreshBalance),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundTop,
              AppColors.backgroundBottom,
              AppColors.scaffoldGradientStart,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    _buildHeroBanner(),
                    const SizedBox(height: 12),
                    ArenaStakeSelector(
                      selectedStake: _selectedStake,
                      onSelected: (v) => setState(() => _selectedStake = v),
                      accentColor: AppColors.gold,
                    ),
                    if (lowBalance) ...[
                      const SizedBox(height: 12),
                      _buildLowBalanceBanner(),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'mg.choose_game'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GameCard(
                      icon: Icons.diamond_rounded,
                      color: AppColors.emerald,
                      title: 'mg.mines'.tr(),
                      desc: 'mg.mines_desc'.tr(),
                      tag: 'mg.tag_strategy'.tr(),
                      multiplierText: '9.5x',
                      payoutText: 'mg.up_to_payout'.tr(args: [
                        '${TokenArenaRules.minesPayout(_selectedStake, TokenArenaRules.minesMaxSafePicks)}',
                      ]),
                      onTap: () => _openGame(
                        (s) => TokenArenaMinesScreen(initialStake: s),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GameCard(
                      icon: Icons.casino_rounded,
                      color: AppColors.gold,
                      title: 'mg.wheel'.tr(),
                      desc: 'mg.wheel_desc'.tr(),
                      tag: 'mg.tag_wheel'.tr(),
                      multiplierText: '3.5x',
                      payoutText: 'mg.up_to_payout'.tr(args: [
                        '${(_selectedStake * 3.5).floor()}',
                      ]),
                      onTap: () => _openGame(
                        (s) => TokenArenaWheelScreen(initialStake: s),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GameCard(
                      icon: Icons.style_rounded,
                      color: AppColors.indigoLight,
                      title: 'mg.higher_lower'.tr(),
                      desc: 'mg.higher_lower_desc'.tr(),
                      tag: 'mg.tag_cards'.tr(),
                      multiplierText: '1.8x',
                      payoutText: 'mg.stake'.tr(args: [
                        '$_selectedStake',
                        '${TokenArenaRules.payout(_selectedStake)}',
                      ]),
                      onTap: () => _openGame(
                        (s) => TokenArenaHiLoScreen(initialStake: s),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GameCard(
                      icon: Icons.grid_view_rounded,
                      color: AppColors.purple,
                      title: 'mg.memory'.tr(),
                      desc: 'mg.memory_desc'.tr(),
                      tag: 'mg.tag_memory'.tr(),
                      multiplierText: '1.8x',
                      payoutText: 'mg.stake'.tr(args: [
                        '$_selectedStake',
                        '${TokenArenaRules.payout(_selectedStake)}',
                      ]),
                      onTap: () => _openGame(
                        (s) => TokenArenaMemoryScreen(initialStake: s),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GameCard(
                      icon: Icons.flash_on_rounded,
                      color: AppColors.amber,
                      title: 'mg.reflex'.tr(),
                      desc: 'mg.reflex_desc'.tr(),
                      tag: 'mg.tag_reflex'.tr(),
                      multiplierText: '1.8x',
                      payoutText: 'mg.stake'.tr(args: [
                        '$_selectedStake',
                        '${TokenArenaRules.payout(_selectedStake)}',
                      ]),
                      onTap: () => _openGame(
                        (s) => TokenArenaReflexScreen(initialStake: s),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: MyNativeAd(height: 65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.indigo.withValues(alpha: 0.28),
            AppColors.purple.withValues(alpha: 0.18),
            AppColors.surface.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'mg.arena_hero_title'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'mg.arena_hero_subtitle'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StepChip(number: '1', label: 'mg.step_1_stake'.tr()),
              const SizedBox(width: 6),
              _StepChip(number: '2', label: 'mg.step_2_play'.tr()),
              const SizedBox(width: 6),
              _StepChip(number: '3', label: 'mg.step_3_win'.tr()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLowBalanceBanner() {
    return GestureDetector(
      onTap: () => openTokenEarnScreen(context, onReturned: _refreshBalance),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.gold,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'mg.low_balance_hint'.tr(args: ['$_selectedStake']),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              'mg.earn_tokens_cta'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String number;
  final String label;

  const _StepChip({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
              ),
              child: Center(
                child: Text(
                  number,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String tag;
  final String multiplierText;
  final String payoutText;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.tag,
    required this.multiplierText,
    required this.payoutText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.42)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            multiplierText,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      payoutText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: color.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
