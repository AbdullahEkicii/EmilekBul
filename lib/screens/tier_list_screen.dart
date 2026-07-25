import 'dart:ui';
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

  // Modern Dark/Neon tema renkleri
  static const Color primaryDark = Color(0xFF0A0A0F);
  static const Color secondaryDark = Color(0xFF1A1A24);
  static const Color cardDark = Color(0xFF252538);
  static const Color neonPurple = Color(0xFF8B5FFF);
  static const Color neonBlue = Color(0xFF4ECDC4);
  static const Color neonPink = Color(0xFFFF6B9D);
  static const Color glowPurple = Color(0xFF6C5CE7);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8CC);
  static const Color surfaceGlow = Color(0xFF2D2D44);

  List<Map<String, dynamic>> _categories = [];

  void _initializeCategories() {
    _categories = [
      {
        'id': 'Genel',
        'name': 'categories.general'.tr(),
        'icon': Icons.leaderboard,
        'color': Colors.amber
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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _dropdownAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
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
            offset: Offset(0, 8),
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
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.error_outline,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFFF3366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 8,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 240, // Increased height to prevent overflow
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            neonPurple.withOpacity(0.8),
            primaryDark,
            primaryDark,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated background particles (reduced for performance)
          RepaintBoundary(
            child: Stack(
              children:
                  List.generate(6, (index) => _buildFloatingParticle(index)),
            ),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [neonPurple, neonBlue],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: neonPurple.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [Colors.white, neonBlue],
                            ).createShader(bounds),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'welcome_screen.tier_list_title'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'welcome_screen.tier_list_subtitle'.tr(),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingParticle(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 10000 + (index * 500)),
      builder: (context, value, child) {
        return Positioned(
          left: (index * 37.0) % 300,
          top: 100 + (value * 100) + (index * 5.0),
          child: Opacity(
            opacity: (0.3 + (index % 3) * 0.2) * (1 - value),
            child: Container(
              width: 4 + (index % 3) * 2,
              height: 4 + (index % 3) * 2,
              decoration: BoxDecoration(
                color: [neonPurple, neonBlue, neonPink][index % 3],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: [neonPurple, neonBlue, neonPink][index % 3],
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernCategorySelector() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'welcome_screen.tier_list_select_category'.tr(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          CompositedTransformTarget(
            link: _dropdownLink,
            child: GestureDetector(
              key: _dropdownKey,
              onTap: _toggleDropdown,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      surfaceGlow.withOpacity(0.8),
                      cardDark.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedCategoryKey != null
                        ? neonPurple.withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedCategoryKey != null
                          ? neonPurple.withOpacity(0.2)
                          : Colors.black26,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_selectedCategoryKey != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [neonPurple, neonBlue],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: neonPurple.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _categories.firstWhere((cat) =>
                              cat['id'] == _selectedCategoryKey)['icon'],
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedCategoryName ?? "",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.category_outlined,
                          color: textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedCategoryName ??
                              'tier_list.select_category_placeholder'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: _isDropdownOpen ? 0.5 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: neonPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: neonPurple,
                          size: 24,
                        ),
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
    final double itemHeight = 68.0;
    final double calculatedHeight =
        (_categories.length * itemHeight).clamp(0.0, 400);
    return Material(
      color: Colors.transparent,
      child: Container(
        height: calculatedHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardDark.withOpacity(0.98),
              secondaryDark.withOpacity(0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 35,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? neonPurple.withOpacity(0.1) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(category['icon'], color: category['color'], size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  category['name'],
                  style: TextStyle(
                    color: isSelected ? neonPurple : textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected) Icon(Icons.check, color: neonPurple, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    Color rankColor;
    IconData rankIcon;
    List<Color> gradientColors;

    switch (index) {
      case 0:
        rankColor = const Color(0xFFFFD700);
        rankIcon = Icons.emoji_events;
        gradientColors = [const Color(0xFFFFD700), const Color(0xFFFFA000)];
        break;
      case 1:
        rankColor = const Color(0xFFC0C0C0);
        rankIcon = Icons.workspace_premium;
        gradientColors = [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)];
        break;
      case 2:
        rankColor = const Color(0xFFCD7F32);
        rankIcon = Icons.military_tech;
        gradientColors = [const Color(0xFFCD7F32), const Color(0xFFA0522D)];
        break;
      default:
        rankColor = neonBlue.withOpacity(0.7);
        rankIcon = Icons.person;
        gradientColors = [neonPurple.withOpacity(0.5), neonBlue.withOpacity(0.5)];
    }

    // Frame Color
    Color frameColor = _getFrameColor(user['equippedFrame']);

    // Glassmorphism effects
    final bool isTop3 = index < 3;
    final double cardOpacity = isTop3 ? 0.95 : 0.8;
    final double borderOpacity = isTop3 ? 0.6 : 0.1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              index * 0.1,
              1.0,
              curve: Curves.easeOutCubic,
            ),
          )),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: index < 3
                    ? [
                        cardDark.withOpacity(cardOpacity),
                        rankColor.withOpacity(0.15),
                      ]
                    : [
                        cardDark.withOpacity(cardOpacity),
                        secondaryDark.withOpacity(cardOpacity * 0.9),
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: index < 3
                    ? rankColor.withOpacity(borderOpacity + 0.2)
                    : Colors.white.withOpacity(borderOpacity),
                width: index < 3 ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: frameColor != Colors.transparent
                      ? frameColor.withOpacity(0.3)
                      : (index < 3
                          ? rankColor.withOpacity(0.4)
                          : neonPurple.withOpacity(0.05)),
                  blurRadius: index < 3 ? 30 : 15,
                  spreadRadius: index < 3 ? 2 : 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (user['equippedFrame'] != null &&
                          user['equippedFrame'] != '0' &&
                          user['equippedFrame'] != 'yok')
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: UserService.getFrameColor(user['equippedFrame']),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: UserService.getFrameColor(user['equippedFrame']).withOpacity(0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: rankColor.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            UserService.getAvatarPath(
                                user['avatarIndex'] ?? '0'),
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                            cacheHeight: 180,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              rankIcon,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      // Crown for top 3
                      if (index < 3)
                        Positioned(
                          top: -12,
                          right: -10,
                          child: Transform.rotate(
                            angle: 0.3,
                            child: Icon(
                              index == 0 ? Icons.workspace_premium : Icons.stars,
                              color: rankColor,
                              size: index == 0 ? 32 : 24,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                AppUtils.localizeUsername(user['username']),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user['activeBadge'] != null) ...[
                              const SizedBox(width: 6),
                              Builder(
                                builder: (context) {
                                  final badge = AchievementService.getBadgeDetails(user['activeBadge']);
                                  if (badge == null) return const SizedBox.shrink();
                                  return Tooltip(
                                    message: badge.titleKey.tr(),
                                    child: Icon(
                                      badge.icon,
                                      color: badge.color,
                                      size: 18,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        if (user['equippedTitle'] != null &&
                            user['equippedTitle'] != 'yok' &&
                            user['equippedTitle'] != '0')
                          Text(
                            (AppConstants.titleKeys[user['equippedTitle']]
                                        ?.tr() ??
                                    user['equippedTitle'].toString())
                                .toUpperCase(),
                            style: TextStyle(
                              color: Colors.amber.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: index < 3 
                                ? [rankColor.withOpacity(0.25), rankColor.withOpacity(0.1)]
                                : [Colors.white.withOpacity(0.1), Colors.transparent],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: index < 3 ? rankColor.withOpacity(0.5) : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            user['rank'] != null
                                ? 'tier_list.rank_format'
                                    .tr(args: [user['rank'].toString()])
                                : 'tier_list.rank_format'
                                    .tr(args: [(index + 1).toString()]),
                            style: TextStyle(
                              color: rankColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: rankColor.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: index < 3 ? 2 : 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${user['points'] ?? 0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 20,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'tier_list.points'.tr(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  neonPurple.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(neonPurple),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [neonPurple, neonBlue],
            ).createShader(bounds),
            child: Text(
              'welcome.loading'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_selectedCategoryKey == null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardDark.withOpacity(0.8),
                secondaryDark.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      neonPurple.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.category_outlined,
                  size: 80,
                  color: neonPurple,
                ),
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [textPrimary, neonBlue],
                ).createShader(bounds),
                child: Text(
                  'welcome_screen.tier_list_select_category'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'welcome_screen.tier_list_select_desc'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (_topUsers.isEmpty && !_isLoading) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardDark.withOpacity(0.8),
                secondaryDark.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      neonPink.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: 80,
                  color: neonPink,
                ),
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [textPrimary, neonPink],
                ).createShader(bounds),
                child: Text(
                  'welcome_screen.tier_list_no_result'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'welcome_screen.tier_list_no_users'
                    .tr(args: [_selectedCategoryName ?? ""]),
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    neonPurple.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildModernCategorySelector()),
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
                  padding: const EdgeInsets.only(bottom: 100),
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
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: primaryDark,
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
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
        backgroundColor: neonPurple,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.refresh, color: Colors.white, size: 28),
      ),
    );
  }
}
