import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/achievement_service.dart';
import '../widgets/my_native_ad.dart';
import '../constants/app_categories.dart';
import '../constants/app_constants.dart';
import '../utils/app_utils.dart';
import 'package:easy_localization/easy_localization.dart';

class PuanlarEkrani extends StatefulWidget {
  const PuanlarEkrani({super.key});

  @override
  State<PuanlarEkrani> createState() => _PuanlarEkraniState();
}

class _PuanlarEkraniState extends State<PuanlarEkrani>
    with TickerProviderStateMixin {
  final LayerLink _dropdownLink = LayerLink();
  OverlayEntry? _dropdownOverlay;
  final GlobalKey _dropdownKey = GlobalKey();
  List<Map<String, dynamic>> _topUsers = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  late AnimationController _dropdownAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isDropdownOpen = false;
  String? _selectedCategoryKey; // Stable DB key (e.g. 'Genel')
  String? _selectedCategoryName; // Localized display name

  // ---------------------------------------------------------------------
  // Design tokens
  // ---------------------------------------------------------------------
  // A single, deliberate palette: deep ink background, one warm metallic
  // accent (champagne gold) used sparingly for identity, and a cool
  // slate accent reserved for secondary/interactive states. Rank colors
  // (gold/silver/bronze) are the only place we allow additional hues,
  // because they encode real information (placement).
  static const Color bgBase = Color(0xFF08090D); // near-black ink
  static const Color bgElevated = Color(0xFF12141C); // panel surface
  static const Color bgCard = Color(0xFF171A24); // card surface
  static const Color bgCardAlt = Color(0xFF1D2029); // card surface, top rows
  static const Color hairline = Color(0xFFFFFFFF); // used only at low alpha

  static const Color accentGold = Color(0xFFD4AF6A); // signature accent
  static const Color accentGoldSoft = Color(0xFFE8CB94);
  static const Color accentSlate = Color(0xFF7C8797); // secondary accent

  static const Color textPrimary = Color(0xFFF3F1EC);
  static const Color textSecondary = Color(0xFF9498A6);
  static const Color textTertiary = Color(0xFF5C6070);

  static const Color rankGold = Color(0xFFE3B94F);
  static const Color rankSilver = Color(0xFFC7CCD6);
  static const Color rankBronze = Color(0xFFC98454);

  static const double radiusLg = 22;
  static const double radiusMd = 16;
  static const double radiusSm = 12;

  List<Map<String, dynamic>> _categories = [];

  void _initializeCategories() {
    _categories = [
      {
        'id': 'Genel',
        'name': 'categories.general'.tr(),
        'icon': Icons.leaderboard_rounded,
        'color': accentGold,
      },
    ];
    for (var cat in AppCategories.categories) {
      _categories.add({
        'id': cat.name, // The static name is our DB key
        'name': cat.key.tr(), // Localized name
        'icon': cat.icon,
        'color': cat.color,
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCategories();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _dropdownAnimationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Başlangıçta Genel kategorisini seç ve yükle
    _selectedCategoryKey = 'Genel';
    _selectedCategoryName = 'categories.general'.tr();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTopUsers();
    });
  }

  @override
  void dispose() {
    _removeDropdownOverlay();
    _animationController.dispose();
    _dropdownAnimationController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _removeDropdownOverlay();
    } else {
      _showDropdownOverlay();
    }
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });
  }

  void _showDropdownOverlay() {
    final overlay = Overlay.of(context);
    final RenderBox renderBox =
        _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _dropdownOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx,
          top: position.dy + renderBox.size.height,
          width: renderBox.size.width,
          child: CompositedTransformFollower(
            link: _dropdownLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 10),
            child: Material(
              color: Colors.transparent,
              child: _buildDropdownMenu(),
            ),
          ),
        );
      },
    );
    overlay.insert(_dropdownOverlay!);
    _dropdownAnimationController.forward();
  }

  void _removeDropdownOverlay() {
    _dropdownAnimationController.reverse();
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  Future<void> _loadTopUsers() async {
    if (_selectedCategoryKey == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final users =
          await UserService.getTopUsersWithContext(_selectedCategoryKey!);
      setState(() {
        _topUsers = users;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String errorMsg = e.toString();
        if (errorMsg.contains('FAILED_PRECONDITION') ||
            errorMsg.contains('index')) {
          errorMsg =
              "Bu sıralama için Firestore İndeksi gerekiyor. Lütfen konsoldaki (Debug Console) linke tıklayarak oluşturun.";
        }
        _showErrorSnackBar('${'common.error'.tr()}: $errorMsg');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3A1F24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.25)),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 28),
      decoration: const BoxDecoration(
        color: bgBase,
        border: Border(
          bottom: BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bgElevated,
                  borderRadius: BorderRadius.circular(radiusSm),
                  border: Border.all(
                    color: accentGold.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: accentGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'welcome_screen.tier_list_title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'welcome_screen.tier_list_subtitle'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Category selector
  // ---------------------------------------------------------------------
  Widget _buildModernCategorySelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 22, 24, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'welcome_screen.tier_list_select_category'.tr(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          CompositedTransformTarget(
            link: _dropdownLink,
            child: GestureDetector(
              key: _dropdownKey,
              onTap: _toggleDropdown,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: bgElevated,
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: Border.all(
                    color: _isDropdownOpen
                        ? accentGold.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accentGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedCategoryKey != null
                            ? _categories.firstWhere((cat) =>
                                cat['id'] == _selectedCategoryKey)['icon']
                            : Icons.category_outlined,
                        color: accentGold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _selectedCategoryName ??
                            'tier_list.select_category_placeholder'.tr(),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: _selectedCategoryKey != null
                              ? textPrimary
                              : textSecondary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 220),
                      turns: _isDropdownOpen ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenu() {
    final double itemHeight = 56.0;
    final double calculatedHeight =
        (_categories.length * itemHeight).clamp(0.0, 360);
    return Material(
      color: Colors.transparent,
      child: Container(
        height: calculatedHeight,
        decoration: BoxDecoration(
          color: bgCardAlt,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radiusMd),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _categories.map((category) {
                return _buildDropdownItem(category);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownItem(Map<String, dynamic> category) {
    bool isSelected = _selectedCategoryKey == category['id'];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategoryKey = category['id'];
            _selectedCategoryName = category['name'];
            _isDropdownOpen = false;
          });
          _removeDropdownOverlay();
          _animationController.reset();
          _loadTopUsers();
        },
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? accentGold.withValues(alpha: 0.08)
                : Colors.transparent,
            border: const Border(
              bottom: BorderSide(color: Color(0x0DFFFFFF), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                category['icon'],
                color: isSelected ? accentGold : textSecondary,
                size: 18,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category['name'],
                  style: TextStyle(
                    color: isSelected ? accentGoldSoft : textPrimary,
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_rounded, color: accentGold, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // User card
  // ---------------------------------------------------------------------
  _RankStyle _rankStyleFor(int index, Map<String, dynamic> user) {
    final String displayRank = user['rank']?.toString() ?? '${index + 1}';
    switch (index) {
      case 0:
        return _RankStyle(rankGold, Icons.emoji_events_rounded, '1');
      case 1:
        return _RankStyle(rankSilver, Icons.workspace_premium_rounded, '2');
      case 2:
        return _RankStyle(rankBronze, Icons.military_tech_rounded, '3');
      default:
        return _RankStyle(accentSlate, Icons.person_rounded, displayRank);
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final style = _rankStyleFor(index, user);
    final bool isTop3 = index < 3;
    final Color frameColor = UserService.getFrameColor(user['equippedFrame']?.toString());

    // Top 3 özel arka plan gradyanı
    final List<Color> cardGradientColors = isTop3
        ? [
            style.color.withValues(alpha: index == 0 ? 0.18 : 0.12),
            bgCardAlt,
          ]
        : [bgCard, bgCard];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index * 0.06).clamp(0.0, 0.6),
              1.0,
              curve: Curves.easeOutCubic,
            ),
          )),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: cardGradientColors,
              ),
              borderRadius: BorderRadius.circular(radiusLg),
              border: Border.all(
                color: isTop3
                    ? style.color.withValues(alpha: index == 0 ? 0.60 : 0.40)
                    : Colors.white.withValues(alpha: 0.06),
                width: isTop3 ? 1.6 : 1.0,
              ),
              boxShadow: isTop3
                  ? [
                      BoxShadow(
                        color: style.color.withValues(alpha: index == 0 ? 0.20 : 0.12),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Rank badge (İlk 3 için daha büyük ve özel simge)
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: isTop3
                          ? Icon(
                              style.icon,
                              color: style.color,
                              size: index == 0 ? 24 : 20,
                              shadows: [
                                Shadow(
                                  color: style.color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                )
                              ],
                            )
                          : Text(
                              style.label,
                              style: const TextStyle(
                                color: textTertiary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Avatar & Frame
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (frameColor != Colors.transparent)
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: frameColor, width: 2.8),
                            boxShadow: [
                              BoxShadow(
                                color: frameColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgElevated,
                          border: Border.all(
                            color: isTop3
                                ? style.color.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            UserService.getAvatarPath(
                                user['avatarIndex']?.toString() ?? '0'),
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            cacheHeight: 160,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              style.icon,
                              color: textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      // 1, 2, 3 için avatar üstündeki taç (crown)
                      if (isTop3)
                        Positioned(
                          top: -10,
                          right: -6,
                          child: Transform.rotate(
                            angle: 0.25,
                            child: Icon(
                              index == 0
                                  ? Icons.workspace_premium_rounded
                                  : Icons.stars_rounded,
                              color: style.color,
                              size: index == 0 ? 26 : 20,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                  offset: const Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Name / title / badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  AppUtils.localizeUsername(user['username']),
                                  style: TextStyle(
                                    fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w700,
                                    fontSize: isTop3 ? 15.5 : 14.5,
                                    color: isTop3 ? Colors.white : textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                            if (user['activeBadge'] != null) ...[
                              const SizedBox(width: 5),
                              Builder(
                                builder: (context) {
                                  final badge =
                                      AchievementService.getBadgeDetails(
                                          user['activeBadge']);
                                  if (badge == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Tooltip(
                                    message: badge.titleKey.tr(),
                                    child: Icon(
                                      badge.icon,
                                      color: badge.color,
                                      size: 14,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        if (user['equippedTitle'] != null &&
                            user['equippedTitle'] != 'yok' &&
                            user['equippedTitle'] != '0') ...[
                          const SizedBox(height: 2),
                          Text(
                            (AppConstants.titleKeys[user['equippedTitle']]
                                        ?.tr() ??
                                    user['equippedTitle'].toString())
                                .toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isTop3 ? style.color : accentGoldSoft,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Points (Puan alanı)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isTop3
                          ? style.color.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(radiusSm),
                      border: Border.all(
                        color: isTop3
                            ? style.color.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${user['points'] ?? 0}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isTop3 ? style.color : textPrimary,
                            fontSize: isTop3 ? 16 : 15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'tier_list.points'.tr(),
                          style: TextStyle(
                            color: isTop3
                                ? style.color.withValues(alpha: 0.8)
                                : textTertiary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Loading / empty states
  // ---------------------------------------------------------------------
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accentGold),
              strokeWidth: 2.6,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'welcome.loading'.tr(),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatePanel({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
        decoration: BoxDecoration(
          color: bgElevated,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentGold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentGold.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 30, color: accentGold),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_selectedCategoryKey == null) {
      return _buildStatePanel(
        icon: Icons.category_outlined,
        title: 'welcome_screen.tier_list_select_category'.tr(),
        description: 'welcome_screen.tier_list_select_desc'.tr(),
      );
    } else if (_topUsers.isEmpty && !_isLoading) {
      return _buildStatePanel(
        icon: Icons.emoji_events_outlined,
        title: 'welcome_screen.tier_list_no_result'.tr(),
        description: 'welcome_screen.tier_list_no_users'
            .tr(args: [_selectedCategoryName ?? ""]),
      );
    }
    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBase,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildModernCategorySelector()),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildLoadingState(),
            )
          else if (_topUsers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100, top: 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildUserCard(_topUsers[index], index);
                  },
                  childCount: _topUsers.length,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: bgBase,
          border: Border(
            top: BorderSide(color: Color(0x0DFFFFFF), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: MyNativeAd(
              height: 120,
              factoryId: 'adFactoryExample',
              refreshInterval: 30,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _selectedCategoryKey = 'Genel';
            _selectedCategoryName = 'categories.general'.tr();
            _topUsers.clear();
            _isDropdownOpen = false;
          });
          _removeDropdownOverlay();
          _dropdownAnimationController.reset();
          _animationController.reset();
          _loadTopUsers();
        },
        backgroundColor: bgElevated,
        foregroundColor: accentGold,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentGold.withValues(alpha: 0.35)),
        ),
        child: const Icon(Icons.refresh_rounded, size: 24),
      ),
    );
  }
}

class _RankStyle {
  final Color color;
  final IconData icon;
  final String label;
  const _RankStyle(this.color, this.icon, this.label);
}
