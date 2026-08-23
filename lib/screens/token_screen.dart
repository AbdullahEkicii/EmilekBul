import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/token_service.dart';
import '../services/review_service.dart';
import '../services/referral_service.dart';
import '../widgets/rewarded_ad_manager.dart';
import '../widgets/glass_container.dart';
import '../widgets/navigation_buttons.dart';
import '../widgets/my_native_ad.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';

class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen>
    with TickerProviderStateMixin {
  int _tokenAmount = 0;
  bool _canClaimDaily = false;
  bool _hasClaimedReview = false;
  String _myInviteCode = '';
  bool _hasUsedReferral = false;
  bool _isLoading = true;
  bool _isAdLoading = false;
  bool _isSubmittingReferral = false;
  Duration _adCooldown = Duration.zero;
  Timer? _cooldownTimer;
  final TextEditingController _referralController = TextEditingController();
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
    _checkAdCooldown();
  }

  void _checkAdCooldown() async {
    final remaining = await RewardedAdManager.getRemainingCooldown();
    if (mounted) {
      setState(() {
        _adCooldown = remaining;
      });
    }
    _cooldownTimer?.cancel();
    if (remaining > Duration.zero) {
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final rem = await RewardedAdManager.getRemainingCooldown();
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _adCooldown = rem;
        });
        if (rem == Duration.zero) {
          timer.cancel();
        }
      });
    }
  }

  String _formatCooldown(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
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
    final hasClaimedReview = await ReviewService.hasClaimedReward();
    final myInviteCode = await ReferralService.getUserInviteCode();
    final hasUsedReferral = await ReferralService.hasUsedReferral();

    if (mounted) {
      setState(() {
        _tokenAmount = tokenAmount;
        _canClaimDaily = canClaimDaily;
        _hasClaimedReview = hasClaimedReview;
        _myInviteCode = myInviteCode;
        _hasUsedReferral = hasUsedReferral;
        _isLoading = false;
      });
    }
  }

  Future<void> _claimDailyReward() async {
    final success = await TokenService.claimDailyReward();
    if (success) {
      setState(() {
        _tokenAmount += 50;
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

  void _showRewardedAd() async {
    final cooldown = await RewardedAdManager.getRemainingCooldown();
    if (cooldown > Duration.zero) {
      final formattedTime = _formatCooldown(cooldown);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('token.reward_ad_cooldown'.tr(args: [formattedTime])),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    _rewardedAdManager.showAd(onRewarded: () async {
      await RewardedAdManager.recordAdWatched();
      await TokenService.addTokens(50);
      final newTokenAmount = await TokenService.getTokenAmount();

      if (mounted) {
        setState(() {
          _tokenAmount = newTokenAmount;
        });
      }

      _checkAdCooldown();

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _loadRewardedAd();
    });
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _myInviteCode));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('referral.code_copied'.tr()),
        backgroundColor: const Color(0xFF8B5CF6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareInviteCode() async {
    final shareText = 'referral.share_msg'.tr(args: [_myInviteCode]);
    HapticFeedback.mediumImpact();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'referral.title'.tr(),
        ),
      );
    } catch (e) {
      // Fallback: Pano kopyalama
      Clipboard.setData(ClipboardData(text: shareText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('referral.code_copied'.tr()),
            backgroundColor: const Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _submitReferralCode() async {
    final code = _referralController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSubmittingReferral = true;
    });

    final result = await ReferralService.redeemReferralCode(code, context);

    if (mounted) {
      setState(() {
        _isSubmittingReferral = false;
      });

      if (result == ReferralResult.success) {
        _referralController.clear();
        await _loadTokenData();
      } else if (result == ReferralResult.alreadyUsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('referral.already_used'.tr()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else if (result == ReferralResult.ownCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('referral.own_code'.tr()),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else if (result == ReferralResult.invalidCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('referral.invalid_code'.tr()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _referralController.dispose();
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
                        const SizedBox(height: 16),
                        _buildReferralCard(),
                        const SizedBox(height: 16),
                        const MyNativeAd(
                          height: 70,
                          factoryId: 'adFactorySmall',
                        ),
                        const SizedBox(height: 16),
                        _buildReviewRewardCard(),
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
            onPressed: (_isAdLoading || _adCooldown > Duration.zero)
                ? null
                : () {
                    _showRewardedAd();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _adCooldown > Duration.zero ? Colors.white10 : Colors.indigoAccent,
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
                : _adCooldown > Duration.zero
                    ? Text(
                        _formatCooldown(_adCooldown),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      )
                    : Text('token.watch'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    final hasUsed = _hasUsedReferral;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      opacity: 0.15,
      border: Border.all(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
        width: 1.2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFA78BFA),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'referral.title'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            '+500',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'referral.desc'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Kendi Davet Kodun
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'referral.your_code'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _myInviteCode.isEmpty ? '...' : _myInviteCode,
                          style: GoogleFonts.firaCode(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _myInviteCode.isEmpty ? null : _copyInviteCode,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: _myInviteCode.isEmpty ? null : _shareInviteCode,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: Text('referral.share_button'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Davet Kodu Girme
          if (hasUsed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'referral.claimed_badge'.tr(),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _referralController,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.firaCode(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'referral.hint'.tr(),
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isSubmittingReferral ? null : _submitReferralCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: _isSubmittingReferral
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'referral.claim_button'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReviewRewardCard() {
    final isClaimed = _hasClaimedReview;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      opacity: isClaimed ? 0.05 : 0.15,
      border: !isClaimed
          ? Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.2)
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: !isClaimed
                  ? Colors.amber.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_rounded,
              color: !isClaimed ? Colors.amber : Colors.white38,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'review.card_title'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'review.card_desc'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: !isClaimed ? Colors.amberAccent.shade100 : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isClaimed
                ? null
                : () {
                    ReviewService.startReviewFlow(
                      context: context,
                      onRewardClaimed: () {
                        _loadTokenData();
                      },
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: !isClaimed ? Colors.amber.shade700 : Colors.white10,
              foregroundColor: Colors.white,
              elevation: !isClaimed ? 2 : 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text(
              isClaimed ? 'review.claimed'.tr() : 'review.rate_action'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
