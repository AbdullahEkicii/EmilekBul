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
import 'shop_screen.dart';
import 'level_progression_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../utils/app_utils.dart';
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
      if (mounted) {
        setState(() {
          _unlockedAchievements = unlocked;
          _unseenAchievements = unseen;
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
                if (mounted)
                  Navigator.of(context).popUntil((route) => route.isFirst);
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
                        const SizedBox(height: 40),
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
    final String avatarPath = _userProfile != null
        ? UserService.getAvatarPath(_userProfile!['avatarIndex'] ?? '0')
        : 'avatars/avatar_1.jpg';

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
                          backgroundImage: ResizeImage(
                            AssetImage(avatarPath),
                            width: 200,
                            height: 200,
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

  Widget _buildEquippedBadge(String? badgeId) {
    final badge = AchievementService.getBadgeDetails(badgeId);
    if (badge == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badge.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badge.color.withOpacity(0.3), width: 1),
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

  Widget _buildAchievementsShowcase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              InkWell(
                onTap: _showAchievementsDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'Daha Fazla',
                    style: TextStyle(
                      color: Colors.amberAccent.shade100,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
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
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? achievement.color.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isUnlocked
                                    ? achievement.color.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: isUnlocked
                                  ? [
                                      BoxShadow(
                                        color: achievement.color
                                            .withValues(alpha: 0.2),
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
                              size: 28,
                            ),
                          ),
                          if (isUnseen)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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
                                child: const Text(
                                  'YENİ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeBadge = _userProfile?['activeBadge'];

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: GlassContainer(
                borderRadius: 28,
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.78,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'achievements.title'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: AchievementService.achievementsList
                                .map((achievement) {
                              final isUnlocked =
                                  unlockedLocal.contains(achievement.id) ||
                                      (_userProfile?['unlockedBadges']
                                                  as List<dynamic>?)
                                              ?.contains(achievement.id) ==
                                          true;
                              final isActive = activeBadge == achievement.id;
                              final isUnseen =
                                  _unseenAchievements.contains(achievement.id);

                              return GestureDetector(
                                  onTap: () async {
                                    if (isUnseen) {
                                      await AchievementService.markAsSeen(
                                          achievement.id);
                                      if (mounted) {
                                        setState(() {
                                          _unseenAchievements
                                              .remove(achievement.id);
                                        });
                                        setDialogState(() {});
                                      }
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isActive
                                            ? achievement.color.withOpacity(0.5)
                                            : Colors.white.withOpacity(0.05),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isUnlocked
                                                    ? achievement.color
                                                        .withOpacity(0.15)
                                                    : Colors.white10,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                achievement.icon,
                                                color: isUnlocked
                                                    ? achievement.color
                                                    : Colors.grey.shade600,
                                                size: 24,
                                              ),
                                            ),
                                            if (isUnseen)
                                              Positioned(
                                                top: -2,
                                                right: -2,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.redAccent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                achievement.titleKey.tr(),
                                                style: TextStyle(
                                                  color: isUnlocked
                                                      ? Colors.white
                                                      : Colors.white60,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                achievement.descKey.tr(),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (!isUnlocked)
                                          Icon(Icons.lock_outline_rounded,
                                              color: Colors.grey.shade600,
                                              size: 20)
                                        else if (isActive)
                                          Text(
                                            'achievements.equipped'.tr(),
                                            style: TextStyle(
                                              color: achievement.color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        else
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white10,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                            onPressed: () async {
                                              await AchievementService
                                                  .setActiveBadge(
                                                      achievement.id);
                                              if (mounted) {
                                                setState(() {
                                                  _userProfile?['activeBadge'] =
                                                      achievement.id;
                                                });
                                                setDialogState(() {});
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text('quests.reward_claimed'
                                                                .tr() ==
                                                            'Ödül başarıyla alındı! 🪙'
                                                        ? 'Rozet başarıyla kuşanıldı: ${achievement.titleKey.tr()}'
                                                        : 'Badge successfully equipped: ${achievement.titleKey.tr()}'),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text(
                                              'achievements.equip'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ));
                            }).toList(),
                          ),
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
