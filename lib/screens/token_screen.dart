import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/token_service.dart';
import '../widgets/rewarded_ad_manager.dart';
import '../widgets/glass_container.dart';
import '../widgets/navigation_buttons.dart';
import 'package:easy_localization/easy_localization.dart';

class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen>
    with TickerProviderStateMixin {
  int _tokenAmount = 0;
  bool _canClaimDaily = false;
  bool _isLoading = true;
  bool _isAdLoading = false;
  final RewardedAdManager _rewardedAdManager = RewardedAdManager();

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTokenData();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    setState(() {
      _isAdLoading = true;
    });
    _rewardedAdManager.loadAd(onAdLoaded: () {
      setState(() {
        _isAdLoading = false;
      });
    });
  }

  void _initAnimations() {
    _orbController =
        AnimationController(duration: const Duration(seconds: 10), vsync: this)
          ..repeat(reverse: true);
    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _orbController, curve: Curves.easeInOut));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  Future<void> _loadTokenData() async {
    final tokenAmount = await TokenService.getTokenAmount();
    final canClaimDaily = await TokenService.canClaimDailyReward();

    setState(() {
      _tokenAmount = tokenAmount;
      _canClaimDaily = canClaimDaily;
      _isLoading = false;
    });
  }

  Future<void> _claimDailyReward() async {
    final success = await TokenService.claimDailyReward();
    if (success) {
      setState(() {
        _tokenAmount += 100;
        _canClaimDaily = false;
      });

      _pulseController.repeat(reverse: true);
      Future.delayed(const Duration(seconds: 2), () {
        _pulseController.stop();
        _pulseController.reset();
      });

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('token.reward_daily_success'.tr()),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showRewardedAd() {
    _rewardedAdManager.showAd(onRewarded: () async {
      await TokenService.addTokens(50);
      final newTokenAmount = await TokenService.getTokenAmount();

      setState(() {
        _tokenAmount = newTokenAmount;
      });

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars, color: Colors.white),
              const SizedBox(width: 8),
              Text('token.reward_ad_success'.tr()),
            ],
          ),
          backgroundColor: Colors.indigo,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _loadRewardedAd();
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildBackgroundOrbs() {
    return AnimatedBuilder(
      animation: _orbAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -50 + (30 * _orbAnimation.value),
              left: -50 + (20 * _orbAnimation.value),
              child: _buildOrb(250, const Color(0xFF667eea).withValues(alpha: 0.3)),
            ),
            Positioned(
              bottom: 100 - (40 * _orbAnimation.value),
              right: -80 + (30 * _orbAnimation.value),
              child: _buildOrb(300, const Color(0xFF764ba2).withValues(alpha: 0.2)),
            ),
            Positioned(
              top: 300 + (50 * (1 - _orbAnimation.value)),
              right: 100,
              child: _buildOrb(150, const Color(0xFFA67BFF).withValues(alpha: 0.15)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 70, spreadRadius: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Center(child: AppBackButton()),
        ),
        title: Text(
          'token.title'.tr(),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0F172A)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          _buildBackgroundOrbs(),

          // Content
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTokenBalanceCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('token.earn'.tr()),
                        const SizedBox(height: 16),
                        _buildDailyRewardCard(),
                        const SizedBox(height: 16),
                        _buildWatchAdCard(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('token.info'.tr()),
                        const SizedBox(height: 16),
                        _buildInfoCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white54,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTokenBalanceCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            blur: 15,
            opacity: 0.1,
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 32, color: Colors.white70),
                const SizedBox(height: 12),
                Text(
                  'token.balance'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white60,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_tokenAmount',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        'token.unit'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyRewardCard() {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      opacity: _canClaimDaily ? 0.15 : 0.05,
      border: _canClaimDaily
          ? Border.all(color: Colors.greenAccent.withValues(alpha: 0.5))
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _canClaimDaily
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: _canClaimDaily ? Colors.greenAccent : Colors.white54,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'token.daily_reward'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _canClaimDaily
                      ? 'token.daily_claim'.tr()
                      : 'token.daily_wait'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _canClaimDaily ? _claimDailyReward : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canClaimDaily ? Colors.green : Colors.white10,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
                _canClaimDaily ? 'token.claim'.tr() : 'token.claimed'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchAdCard() {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      opacity: 0.1,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.indigoAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'token.watch_ad'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'token.watch_earn'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isAdLoading
                ? null
                : () {
                    if (!_isAdLoading) {
                      _showRewardedAd();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: _isAdLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('token.watch'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      opacity: 0.05,
      child: Column(
        children: [
          _buildInfoRow('token.cost_quiz'.tr(),
              'token.cost_tokens'.tr(args: ['10']), Colors.redAccent),
          const Divider(color: Colors.white10),
          _buildInfoRow(
              'token.reward_easy'.tr(),
              'token.reward_points_tokens'
                  .tr(args: ['2', 'category_ui.points'.tr(), '2']),
              Colors.white70),
          _buildInfoRow(
              'token.reward_medium'.tr(),
              'token.reward_points_tokens'
                  .tr(args: ['3', 'category_ui.points'.tr(), '3']),
              Colors.white70),
          _buildInfoRow(
              'token.reward_hard'.tr(),
              'token.reward_points_tokens'
                  .tr(args: ['4', 'category_ui.points'.tr(), '4']),
              Colors.white70),
          _buildInfoRow(
              'token.reward_impossible'.tr(),
              'token.reward_points_tokens'
                  .tr(args: ['6', 'category_ui.points'.tr(), '6']),
              Colors.amberAccent),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
