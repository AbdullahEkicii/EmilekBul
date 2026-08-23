import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../services/user_service.dart';
import '../services/sound_service.dart';
import '../services/performance_service.dart';
import '../services/fullscreen_service.dart';
import '../services/achievement_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/navigation_buttons.dart';
import '../widgets/my_native_ad.dart';
import 'shop_screen.dart';
import 'level_progression_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../constants/app_languages.dart';
import '../utils/app_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_register_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _orbController;

  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _scaleAnimation;
  Animation<double>? _orbAnimation;

  Map<String, dynamic>? _userProfile;
  User? currentUser;
  bool isLoading = false;
  bool _isGuest = false;
  List<String> _unlockedAchievements = [];
  List<String> _unseenAchievements = [];
  List<String> _claimedAchievements = [];
  int _duelWins = 0;
  String _selectedAchievementCategory = 'all';

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    // We don't know if linked yet, so assume guest if anonymous until profile loads
    _isGuest = currentUser?.isAnonymous ?? false;
    _loadUserProfile();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _orbController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation =
        Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (currentUser == null) return;
    try {
      final data = await UserService.getUserProfile(currentUser!.uid);
      final rank = await UserService.getUserRank(
          currentUser!.uid, 'Genel'); // Rank'i çek
      final monthlyPoints = await UserService.getUserMonthlyPoints(
          currentUser!.uid); // Aylık puanı çek
      final unlocked = await AchievementService.getUnlockedAchievements();
      final unseen = await AchievementService.getUnseenAchievements();
      final claimed = await AchievementService.getClaimedAchievements();
      final prefs = await SharedPreferences.getInstance();
      final duelWins = prefs.getInt('duel_wins_count') ?? 0;

      if (mounted) {
        setState(() {
          _unlockedAchievements = unlocked;
          _unseenAchievements = unseen;
          _claimedAchievements = claimed;
          _duelWins = duelWins;
          _userProfile = data;
          if (_userProfile != null) {
            _userProfile!['rank'] = rank; // Profile ekle
            _userProfile!['monthlyPoints'] = monthlyPoints; // Profile ekle
          }
          final isLinked = _userProfile?['playGamesId'] != null;
          _isGuest = (currentUser?.isAnonymous ?? false) && !isLinked;
        });
      }
    } catch (e) {
      // Error handling
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('account.logout_confirm_title'.tr(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('account.logout_confirm_msg'.tr(),
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('account.cancel'.tr(),
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('account.confirm_logout'.tr(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundOrbs() {
    if (_orbAnimation == null) return const SizedBox.shrink();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbAnimation!,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: 50 + (20 * _orbAnimation!.value),
                right: -50,
                child: _buildOrb(
                    250, const Color(0xFF6366F1).withValues(alpha: 0.15)),
              ),
              Positioned(
                bottom: 100 - (30 * _orbAnimation!.value),
                left: -80,
                child: _buildOrb(
                    300, const Color(0xFFA855F7).withValues(alpha: 0.1)),
              ),
            ],
          );
        },
      ),
    );
  }

// ... (skip down to buildMenuItem) ...

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: GlassContainer(
          opacity: 0.05,
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
          useBlur: false, // Performance optimization
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 20)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
          ),
          _buildBackgroundOrbs(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildProfileCard(),
                        if (_isGuest) _buildGuestWarningCard(),
                        const SizedBox(height: 12),
                        _buildLevelProgressCard(),
                        const SizedBox(height: 20),
                        if (!_isGuest) _buildAchievementsShowcase(),
                        if (!_isGuest) const SizedBox(height: 20),
                        _buildMenuSection(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          AppBackButton(),
          const SizedBox(width: 16),
          Text(
            'account.title'.tr(),
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestWarningCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orangeAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'account.guest_warning'.tr(),
                  style: TextStyle(
                      color: Colors.orangeAccent.shade100, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginRegisterScreen(
                      onStart: () {}, // No-op, handled in screen
                      isForced: false,
                    ),
                  ),
                ).then((_) => _loadUserProfile());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('account.login_register'.tr(),
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final bool hasAvatar = _userProfile != null &&
        UserService.hasAvatar(_userProfile!['avatarIndex']?.toString());
    final String avatarPath = hasAvatar
        ? UserService.getAvatarPath(_userProfile!['avatarIndex']!.toString())
        : '';

    if (_fadeAnimation == null || _scaleAnimation == null) {
      return const SizedBox.shrink();
    }
    return FadeTransition(
      opacity: _fadeAnimation!,
      child: ScaleTransition(
        scale: _scaleAnimation!,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: GlassContainer(
            opacity: 0.1,
            borderRadius: 30,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Frame
                    if (_userProfile?['equippedFrame'] != null &&
                        _userProfile?['equippedFrame'] != '0')
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                _getFrameColor(_userProfile?['equippedFrame']),
                            width: 6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _getFrameColor(_userProfile?['equippedFrame'])
                                      .withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                    Container(
                      width: 110,
                      height: 110,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Color(0xFF1E293B)),
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.transparent,
                          backgroundImage: hasAvatar
                              ? ResizeImage(
                                  AssetImage(avatarPath),
                                  width: 200,
                                  height: 200,
                                )
                              : null,
                          child: hasAvatar
                              ? null
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 55,
                                  color: Colors.white70,
                                ),
                        ),
                      ),
                    ),
                    if (!_isGuest)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: Color(0xFF6366F1), shape: BoxShape.circle),
                          child: const Icon(Icons.verified_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                if (_userProfile?['equippedTitle'] != null &&
                    _userProfile?['equippedTitle'] != 'yok' &&
                    _userProfile?['equippedTitle'] != '0')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      (AppConstants.titleKeys[_userProfile!['equippedTitle']]
                                  ?.tr() ??
                              _userProfile!['equippedTitle'].toString())
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _isGuest
                      ? 'common.guest_user'.tr()
                      : AppUtils.localizeUsername(_userProfile?['username']),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                if (!_isGuest)
                  Text(
                    currentUser?.email ?? '',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500),
                  ),
                if (!_isGuest && _userProfile?['activeBadge'] != null)
                  _buildEquippedBadge(_userProfile!['activeBadge']),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickStat('account.rank'.tr(),
                        '#${_userProfile?['rank'] ?? '--'}'),
                    _buildStatDivider(),
                    _buildQuickStat('account.monthly_score'.tr(),
                        '${_userProfile?['monthlyPoints'] ?? '0'}'),
                    _buildStatDivider(),
                    _buildQuickStat('account.total_score'.tr(),
                        '${_userProfile?['totalPoints'] ?? '0'}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelProgressCard() {
    if (_userProfile == null) return const SizedBox.shrink();

    final int level = _userProfile!['level'] ?? 1;
    final int quizzes = _userProfile!['completedQuizzes'] ?? 0;
    final int nextLevelQuizzes =
        UserService.getQuizzesNeededForNextLevel(level);
    final int prevLevelQuizzes =
        level == 1 ? 0 : UserService.getQuizzesNeededForNextLevel(level - 1);

    final progress =
        (quizzes - prevLevelQuizzes) / (nextLevelQuizzes - prevLevelQuizzes);
    final displayProgress = progress.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassContainer(
        opacity: 0.05,
        borderRadius: 20,
        padding: const EdgeInsets.all(0),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LevelProgressionScreen()),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.stars_rounded,
                          color: Colors.amber, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'level_progression.title'.tr(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${'level_system.level'.tr()} $level',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: displayProgress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 25,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildToggleMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: GlassContainer(
          opacity: 0.05,
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
          useBlur: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: color,
                  activeTrackColor: color.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.white10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    if (_slideAnimation == null) return const SizedBox.shrink();
    return SlideTransition(
      position: _slideAnimation!,
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.edit_rounded,
            title: 'account.edit_profile'.tr(),
            subtitle: 'account.edit_profile_desc'.tr(),
            color: Colors.blueAccent,
            onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()))
                .then((_) => _loadUserProfile()),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: MyNativeAd(
              height: 70,
              factoryId: 'adFactorySmall',
            ),
          ),
          _buildMenuItem(
            icon: Icons.shopping_bag_rounded,
            title: 'account.shop'.tr(),
            subtitle: 'account.shop_desc'.tr(),
            color: Colors.amber,
            onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ShopScreen()))
                .then((_) => _loadUserProfile()),
          ),
          _buildToggleMenuItem(
            icon: Icons.volume_up_rounded,
            title: 'settings.sound_effects'.tr(),
            subtitle: 'settings.sound_effects_desc'.tr(),
            color: Colors.teal,
            value: SoundService.isSoundEnabled,
            onChanged: (val) async {
              await SoundService.setSoundEnabled(val);
              setState(() {});
            },
          ),
          _buildToggleMenuItem(
            icon: Icons.music_note_rounded,
            title: 'settings.music'.tr(),
            subtitle: 'settings.music_desc'.tr(),
            color: Colors.purpleAccent,
            value: SoundService.isMusicEnabled,
            onChanged: (val) async {
              await SoundService.setMusicEnabled(val);
              setState(() {});
            },
          ),
          _buildToggleMenuItem(
            icon: Icons.speed_rounded,
            title: 'settings.performance_mode'.tr(),
            subtitle: 'settings.performance_mode_desc'.tr(),
            color: Colors.orangeAccent,
            value: PerformanceService.isPerformanceMode,
            onChanged: (val) async {
              await PerformanceService.setPerformanceMode(val);
              setState(() {});
            },
          ),
          _buildToggleMenuItem(
            icon: Icons.fullscreen_rounded,
            title: 'settings.full_screen'.tr(),
            subtitle: 'settings.full_screen_desc'.tr(),
            color: Colors.blueGrey,
            value: FullScreenService.isFullScreen,
            onChanged: (val) async {
              await FullScreenService.setFullScreen(val);
              setState(() {});
            },
          ),
          _buildMenuItem(
            icon: Icons.language_rounded,
            title: 'settings.language'.tr(),
            subtitle: 'settings.language_desc'.tr(),
            color: Colors.indigoAccent,
            onTap: _showLanguageDialog,
          ),
          if (!_isGuest) // Only show password change if not guest
            _buildMenuItem(
              icon: Icons.shield_moon_rounded,
              title: 'account.security'.tr(),
              subtitle: 'account.security_desc'.tr(),
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
          _buildMenuItem(
            icon: Icons.logout_rounded,
            title: 'account.logout'.tr(),
            subtitle: 'account.logout_desc'.tr(),
            color: Colors.redAccent,
            onTap: _showSignOutDialog,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final currentCode = context.locale.languageCode;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0x2EFFFFFF), width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.language_rounded, color: Colors.indigoAccent, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'settings.language'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: AppLanguages.languages.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final lang = AppLanguages.languages[index];
                    final isSelected = lang.code == currentCode;

                    return GestureDetector(
                      onTap: () async {
                        await context.setLocale(Locale(lang.code));
                        if (context.mounted) {
                          Navigator.pop(context);
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.indigoAccent.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.indigoAccent
                                : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(lang.flag, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                lang.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.indigoAccent : Colors.white,
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Colors.indigoAccent, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEquippedBadge(String? badgeId) {
    final badge = AchievementService.getBadgeDetails(badgeId);
    if (badge == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badge.color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, color: badge.color, size: 16),
          const SizedBox(width: 6),
          Text(
            badge.titleKey.tr().toUpperCase(),
            style: TextStyle(
              color: badge.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  int _getAchievementProgress(Achievement a, SharedPreferences? prefs) {
    if (_unlockedAchievements.contains(a.id) ||
        (_userProfile?['unlockedBadges'] as List<dynamic>?)?.contains(a.id) == true) {
      return a.maxProgress;
    }
    switch (a.id) {
      case 'first_step':
      case 'bronze_scholar':
      case 'silver_scholar':
      case 'gold_scholar':
        final quizzes = (_userProfile?['completedQuizzes'] as num?)?.toInt() ?? 0;
        return quizzes.clamp(0, a.maxProgress);
      case 'level_five':
        final level = (_userProfile?['level'] as num?)?.toInt() ?? 1;
        return level.clamp(0, a.maxProgress);
      case 'smart_shopper':
        final ownedFrames = (_userProfile?['ownedFrames'] as List?)
                ?.where((f) => f != '0' && f != 'yok' && f.toString().isNotEmpty)
                .length ??
            0;
        final ownedTitles = (_userProfile?['ownedTitles'] as List?)
                ?.where((t) => t != '0' && t != 'yok' && t.toString().isNotEmpty)
                .length ??
            0;
        final ownedAvatars = (_userProfile?['ownedAvatars'] as List?)
                ?.where((a) => a != '0' && a != 'yok' && a.toString().isNotEmpty)
                .length ??
            0;
        final count = ownedFrames + ownedTitles + ownedAvatars;
        return count.clamp(0, a.maxProgress);
      case 'duel_initiate':
      case 'duel_warrior':
        final wins = prefs?.getInt('duel_wins_count') ?? _duelWins;
        return wins.clamp(0, a.maxProgress);
      default:
        return 0;
    }
  }

  Widget _buildAchievementsShowcase() {
    final unlockedCount = _unlockedAchievements.length;
    final totalCount = AchievementService.achievementsList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'achievements.title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$unlockedCount/$totalCount',
                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showAchievementsDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'achievements.more'.tr(),
                        style: TextStyle(
                          color: Colors.amberAccent.shade100,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, color: Colors.amberAccent.shade100, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 115,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: AchievementService.achievementsList.length,
            itemBuilder: (context, index) {
              final achievement = AchievementService.achievementsList[index];
              final isUnlocked =
                  _unlockedAchievements.contains(achievement.id) ||
                      (_userProfile?['unlockedBadges'] as List<dynamic>?)
                              ?.contains(achievement.id) ==
                          true;
              final isUnseen = _unseenAchievements.contains(achievement.id);
              final isClaimed = _claimedAchievements.contains(achievement.id) ||
                  (_userProfile?['claimedBadges'] as List<dynamic>?)
                          ?.contains(achievement.id) ==
                      true;

              return GestureDetector(
                onTap: () async {
                  if (isUnseen) {
                    await AchievementService.markAsSeen(achievement.id);
                    if (mounted) {
                      setState(() {
                        _unseenAchievements.remove(achievement.id);
                      });
                    }
                  }
                  _showAchievementsDialog();
                },
                child: Container(
                  width: 84,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? achievement.color.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isUnlocked
                                    ? achievement.color.withValues(alpha: 0.6)
                                    : Colors.white12,
                                width: 1.5,
                              ),
                              boxShadow: isUnlocked
                                  ? [
                                      BoxShadow(
                                        color: achievement.color
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              isUnlocked
                                  ? achievement.icon
                                  : Icons.lock_outline_rounded,
                              color: isUnlocked
                                  ? achievement.color
                                  : Colors.white30,
                              size: 26,
                            ),
                          ),
                          if (isUnseen)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                                child: Text(
                                  'common.new'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            )
                          else if (isUnlocked && !isClaimed)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 10),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        achievement.titleKey.tr(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.white54,
                          fontSize: 10,
                          fontWeight:
                              isUnlocked ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAchievementsDialog() async {
    final unlockedLocal = await AchievementService.getUnlockedAchievements();
    final claimedLocal = await AchievementService.getClaimedAchievements();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeBadge = _userProfile?['activeBadge'];
            final unlockedCount = unlockedLocal.length;
            final totalCount = AchievementService.achievementsList.length;

            final filteredAchievements = AchievementService.achievementsList.where((a) {
              if (_selectedAchievementCategory == 'all') return true;
              return a.category == _selectedAchievementCategory;
            }).toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: GlassContainer(
                borderRadius: 28,
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.82,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'achievements.title'.tr(),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$unlockedCount / $totalCount ${'achievements.title'.tr().toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amberAccent.shade100,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildCategoryFilterChip('all', 'achievements.all'.tr(), setDialogState),
                            const SizedBox(width: 8),
                            _buildCategoryFilterChip('quiz', 'achievements.quiz_category'.tr(), setDialogState),
                            const SizedBox(width: 8),
                            _buildCategoryFilterChip('duel', 'achievements.duel_category'.tr(), setDialogState),
                            const SizedBox(width: 8),
                            _buildCategoryFilterChip('social', 'achievements.social_category'.tr(), setDialogState),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Achievements List
                      Flexible(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filteredAchievements.length,
                          itemBuilder: (context, index) {
                            final achievement = filteredAchievements[index];
                            final isUnlocked =
                                unlockedLocal.contains(achievement.id) ||
                                    (_userProfile?['unlockedBadges']
                                                as List<dynamic>?)
                                            ?.contains(achievement.id) ==
                                        true;
                            final isActive = activeBadge == achievement.id;
                            final isUnseen =
                                _unseenAchievements.contains(achievement.id);
                            final isClaimed = claimedLocal.contains(achievement.id) ||
                                (_userProfile?['claimedBadges'] as List<dynamic>?)
                                        ?.contains(achievement.id) ==
                                    true;
                            final progress = _getAchievementProgress(achievement, prefs);
                            final progressRatio = achievement.maxProgress > 0
                                ? (progress / achievement.maxProgress).clamp(0.0, 1.0)
                                : (isUnlocked ? 1.0 : 0.0);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUnlocked
                                    ? achievement.color.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? achievement.color
                                      : (isUnlocked
                                          ? achievement.color.withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.06)),
                                  width: isActive ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Icon
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isUnlocked
                                                  ? achievement.color.withValues(alpha: 0.2)
                                                  : Colors.white.withValues(alpha: 0.05),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              achievement.icon,
                                              color: isUnlocked
                                                  ? achievement.color
                                                  : Colors.grey.shade600,
                                              size: 22,
                                            ),
                                          ),
                                          if (isUnseen)
                                            Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),

                                      // Title & Description
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    achievement.titleKey.tr(),
                                                    style: TextStyle(
                                                      color: isUnlocked
                                                          ? Colors.white
                                                          : Colors.white60,
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 11),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '+${achievement.tokenReward}',
                                                        style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              achievement.descKey.tr(),
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Progress Bar & Action Button
                                  Row(
                                    children: [
                                      // Progress Bar
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'achievements.progress'.tr(),
                                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9.5),
                                                ),
                                                Text(
                                                  '$progress / ${achievement.maxProgress}',
                                                  style: TextStyle(
                                                    color: isUnlocked ? achievement.color : Colors.white60,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progressRatio,
                                                minHeight: 5,
                                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  isUnlocked ? achievement.color : const Color(0xFF6366F1),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Action Buttons
                                      if (!isUnlocked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, color: Colors.grey.shade600, size: 13),
                                            ],
                                          ),
                                        )
                                      else if (!isClaimed)
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () async {
                                            final success = await AchievementService.claimReward(achievement.id, context);
                                            if (success && mounted) {
                                              setState(() {
                                                _claimedAchievements.add(achievement.id);
                                              });
                                              setDialogState(() {
                                                claimedLocal.add(achievement.id);
                                              });
                                            }
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                'achievements.claim_reward'.tr(args: [achievement.tokenReward.toString()]),
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: achievement.color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: achievement.color.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            'achievements.equipped'.tr(),
                                            style: TextStyle(
                                              color: achievement.color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        )
                                      else
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: achievement.color.withValues(alpha: 0.5)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () async {
                                            await AchievementService.setActiveBadge(achievement.id);
                                            if (mounted) {
                                              setState(() {
                                                _userProfile?['activeBadge'] = achievement.id;
                                              });
                                              setDialogState(() {});
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'achievements.badge_equipped'.tr(args: [achievement.titleKey.tr()]),
                                                  ),
                                                  backgroundColor: Colors.green,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            'achievements.equip'.tr(),
                                            style: TextStyle(
                                              color: achievement.color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilterChip(String catId, String title, StateSetter setDialogState) {
    final isSelected = _selectedAchievementCategory == catId;
    return InkWell(
      onTap: () {
        setDialogState(() {
          _selectedAchievementCategory = catId;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF818CF8)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getFrameColor(String? frameId) {
    switch (frameId) {
      case '1':
        return Colors.amber;
      case '2':
        return Colors.cyanAccent;
      case '3':
        return Colors.redAccent;
      default:
        return Colors.transparent;
    }
  }
}
