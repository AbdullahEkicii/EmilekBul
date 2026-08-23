import 'package:emilekbul/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:emilekbul/widgets/token_widget.dart';
import 'package:emilekbul/services/token_service.dart';
import 'package:emilekbul/widgets/glass_container.dart';
import 'package:emilekbul/widgets/navigation_buttons.dart';
import 'package:emilekbul/widgets/my_native_ad.dart';

import '../models/category_model.dart';
import '../constants/app_categories.dart';
import '../screens/token_screen.dart';
import '../utils/app_utils.dart';

class KategoriScreen extends StatefulWidget {
  final Function(String category, String difficulty, int duration, {bool isDuel}) onStartQuiz;
  final VoidCallback onStart;

  const KategoriScreen({
    super.key,
    required this.onStartQuiz,
    required this.onStart,
  });

  @override
  State<KategoriScreen> createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen>
    with TickerProviderStateMixin {
  String? _selectedCategory;
  String? _selectedDifficulty;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _buttonPulseController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _buttonPulseAnimation;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _difficultyKey = GlobalKey();
  final GlobalKey _startButtonKey = GlobalKey();

  // Kategori bilgilerini merkezi yerden alıyor
  static final List<CategoryItem> _categories = AppCategories.categories;

  static final List<DifficultyItem> _difficulties = [
    DifficultyItem(
      "Kolay",
      const Color(0xFF96CEB4),
      Icons.sentiment_satisfied,
      "category_ui.difficulty_desc.easy",
      25,
      "category_ui.difficulty.easy",
    ),
    DifficultyItem(
      "Orta",
      const Color(0xFFFECA57),
      Icons.sentiment_neutral,
      "category_ui.difficulty_desc.medium",
      35,
      "category_ui.difficulty.medium",
    ),
    DifficultyItem(
      "Zor",
      const Color(0xFFFF6B6B),
      Icons.sentiment_very_dissatisfied,
      "category_ui.difficulty_desc.hard",
      40,
      "category_ui.difficulty.hard",
    ),
    DifficultyItem(
      "Imkansız",
      const Color(0xFF22223B),
      Icons.warning_amber_rounded,
      "category_ui.difficulty_desc.impossible",
      45,
      "category_ui.difficulty.impossible",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();

    // Düşük bakiye kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLowBalance();
      _cleanOldTests();
    });
  }

  Future<void> _checkLowBalance() async {
    if (!mounted) return;

    final tokenAmount = await TokenService.getTokenAmount();
    if (tokenAmount <= 10) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('category_ui.token_warning'.tr()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const TokenScreen(),
        ),
      );
    }
  }

  void _cleanOldTests() async {
    try {
      await DatabaseHelper.instance.deleteOldTests(days: 14);
      debugPrint('Old tests cleaned.');
    } catch (e) {
      debugPrint('Temizleme hatası: $e');
    }
  }

  String puan(String? difficult) {
    if (difficult == "Kolay") {
      return "2 ${'category_ui.points'.tr()}";
    } else if (difficult == "Orta") {
      return "3 ${'category_ui.points'.tr()}";
    } else if (difficult == "Zor") {
      return "4 ${'category_ui.points'.tr()}";
    } else if (difficult == "Imkansız") {
      return "6 ${'category_ui.points'.tr()}";
    } else {
      return "3 ${'category_ui.points'.tr()}";
    }
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _buttonPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _buttonPulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }

  void _scrollToDifficulty() {
    final context = _difficultyKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _scrollToStartButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _startButtonKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
          alignment: 1.0,
        );
      }
    });
  }

  void _startButtonPulse() {
    _buttonPulseController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _buttonPulseController.stop();
      _buttonPulseController.reset();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _buttonPulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(child: _buildHeader()),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: RepaintBoundary(child: _buildCategorySection()),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: MyNativeAd(
                          height: 70,
                          factoryId: 'adFactorySmall',
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child:
                            RepaintBoundary(child: _buildDifficultySection()),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: _buildQuizPreview(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: _buildActionButtons(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 14,
            child: AppHomeButton(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => WelcomeScreen(
                      onStart: widget.onStart,
                      skipLoading: true,
                    ),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: GlassContainer(
              borderRadius: 50,
              opacity: 0.15,
              padding: const EdgeInsets.all(4),
              child: const TokenWidget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          children: [
            Hero(
              tag: 'app_logo',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Image.asset('lib/assets/emilekbul2.png',
                    width: 40, height: 40, cacheWidth: 120, cacheHeight: 120),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'category_ui.title'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'category_ui.subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final weeklyBonuses = AppCategories.getWeeklyBonusCategories();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        opacity: 0.1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HAFTALIK 2X BONUS KATEGORİLER VİTRİNİ ---
            _buildWeeklyBonusHeader(),
            const SizedBox(height: 12),
            _buildWeeklyBonusRow(weeklyBonuses),
            const SizedBox(height: 24),

            // --- TÜM KATEGORİLER BAŞLIĞI ---
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_mosaic_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'category_ui.all_categories'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedCategory != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'category_ui.selected'.tr(args: [
                          _getCategoryDisplayName(_selectedCategory!)
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _buildCategoryGrid(),
          ],
        ),
      ),
    );
  }

  String _getCategoryDisplayName(String categoryName) {
    try {
      final allCats = [..._categories, ...AppCategories.bonusPoolCategories];
      final match = allCats.firstWhere((c) => c.name == categoryName);
      return match.key.tr();
    } catch (_) {
      return categoryName;
    }
  }

  Widget _buildWeeklyBonusHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9F43).withValues(alpha: 0.25),
            const Color(0xFFFF5252).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9F43).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9F43), Color(0xFFFF5252)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'category_ui.weekly_bonus_title'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFD56B),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'category_ui.weekly_bonus_badge'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'category_ui.weekly_bonus_subtitle'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBonusRow(List<CategoryItem> bonusCategories) {
    return Row(
      children: bonusCategories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final isSelected = _selectedCategory == category.name;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: index == bonusCategories.length - 1 ? 0 : 4,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category.name);
                _triggerHapticFeedback();
                Future.delayed(const Duration(milliseconds: 300), () {
                  _scrollToDifficulty();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              category.color.withValues(alpha: 0.4),
                              category.color.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              category.color.withValues(alpha: 0.12),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD56B)
                          : category.color.withValues(alpha: 0.4),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: category.color.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              category.icon,
                              size: 22,
                              color: isSelected ? Colors.white : category.color,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flash_on, color: Colors.white, size: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.key.tr(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F43).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '2X ⚡',
                          style: TextStyle(
                            color: Color(0xFFFFD56B),
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _categories.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = _selectedCategory == category.name;

        return RepaintBoundary(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = category.name);
              _triggerHapticFeedback();

              // Otomatik scroll
              Future.delayed(const Duration(milliseconds: 300), () {
                _scrollToDifficulty();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color:
                    isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? category.color
                      : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: category.color.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category.color.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      category.icon,
                      size: 28,
                      color: isSelected ? category.color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      category.key.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? category.color : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.descriptionKey.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? category.color.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDifficultySection() {
    final isEnabled = _selectedCategory != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: GlassContainer(
        key: _difficultyKey,
        padding: const EdgeInsets.all(24),
        opacity: isEnabled ? 0.1 : 0.05,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.signal_cellular_alt_rounded,
                  color: Colors.white.withValues(alpha: isEnabled ? 0.9 : 0.5),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'category_ui.difficulty_level'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: isEnabled ? 1.0 : 0.5),
                  ),
                ),
              ],
            ),
            if (!isEnabled) ...[
              const SizedBox(height: 12),
              Text(
                'category_ui.select_category_first'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildDifficultySelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ekran genişliğine göre font boyutlarını ayarla
        double screenWidth = constraints.maxWidth;
        double titleFontSize = screenWidth < 350 ? 11 : 12;
        double timeFontSize = screenWidth < 350 ? 8 : 9;
        double iconSize = screenWidth < 350 ? 20 : 22;

        return Row(
          children: _difficulties.asMap().entries.map((entry) {
            int index = entry.key;
            DifficultyItem difficulty = entry.value;
            final isSelected = _selectedDifficulty == difficulty.name;
            final isEnabled = _selectedCategory != null;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 4, // Arası boşluğu azalttım
                  right: index == _difficulties.length - 1 ? 0 : 4,
                ),
                child: GestureDetector(
                  onTap: isEnabled
                      ? () {
                          setState(() => _selectedDifficulty = difficulty.name);
                          _triggerHapticFeedback();
                          _startButtonPulse();
                          _scrollToStartButton();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      vertical: 12, // Padding'i azalttım
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected && isEnabled
                          ? Colors.white
                          : Colors.white.withValues(alpha: isEnabled ? 0.15 : 0.05),
                      borderRadius:
                          BorderRadius.circular(16), // Radius'u azalttım
                      border: Border.all(
                        color: isSelected && isEnabled
                            ? difficulty.color
                            : Colors.white.withValues(alpha: isEnabled ? 0.3 : 0.1),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          difficulty.icon,
                          size: iconSize,
                          color: isSelected && isEnabled
                              ? difficulty.color
                              : Colors.white.withValues(alpha: isEnabled ? 0.8 : 0.3),
                        ),
                        const SizedBox(height: 6),
                        // Metni daha kompakt hale getir
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            difficulty.key.tr(),
                            style: TextStyle(
                              color: isSelected && isEnabled
                                  ? difficulty.color
                                  : Colors.white
                                      .withValues(alpha: isEnabled ? 0.8 : 0.3),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: titleFontSize,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'category_ui.seconds'
                                .tr(args: [difficulty.time.toString()]),
                            style: TextStyle(
                              color: isSelected && isEnabled
                                  ? difficulty.color.withValues(alpha: 0.7)
                                  : Colors.white
                                      .withValues(alpha: isEnabled ? 0.5 : 0.2),
                              fontSize: timeFontSize,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildQuizPreview() {
    if (_selectedCategory == null || _selectedDifficulty == null) {
      return const SizedBox.shrink();
    }

    final allCats = [..._categories, ...AppCategories.bonusPoolCategories];
    final selectedCategoryItem = allCats.firstWhere(
      (cat) => cat.name == _selectedCategory,
      orElse: () => allCats.first,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: 1.0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'category_ui.preview'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPreviewItem(
                    Icons.category,
                    'category_ui.preview_category'.tr(),
                    selectedCategoryItem.key.tr(),
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.speed,
                    'category_ui.preview_difficulty'.tr(),
                    _difficulties
                        .firstWhere((d) => d.name == _selectedDifficulty)
                        .key
                        .tr(),
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.point_of_sale,
                    'category_ui.preview_score'.tr(),
                    puan(_selectedDifficulty),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPreviewItem(
                    Icons.token,
                    'category_ui.preview_cost'.tr(),
                    'category_ui.token_cost'.tr(),
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.card_giftcard,
                    'category_ui.preview_reward'.tr(),
                    '${_getTokenRewardForDifficulty(_selectedDifficulty!)} Token',
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.card_giftcard,
                    'category_ui.preview_joker'.tr(),
                    'category_ui.joker_cost'.tr(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(IconData icon, String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 16),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final bool isEnabled =
        _selectedCategory != null && _selectedDifficulty != null;

    int getDurationForDifficulty(String? difficulty) {
      switch (difficulty) {
        case 'Kolay':
          return 15;
        case 'Orta':
          return 25;
        case 'Zor':
          return 30;
        case 'Imkansız':
          return 35;
        default:
          return 25;
      }
    }

    return Column(
      key: _startButtonKey,
      children: [
        AnimatedBuilder(
          animation: _buttonPulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isEnabled ? _buttonPulseAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: isEnabled
                      ? const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFF8F8F8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade300, Colors.grey.shade400],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isEnabled
                        ? () async {
                            HapticFeedback.mediumImpact();

                            // 1. İnternet Bağlantısı Kontrolü
                            final hasInternet = await AppUtils.hasInternetConnection();
                            if (!hasInternet) {
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 28),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'errors.no_internet_title'.tr(),
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    'errors.no_internet_ai'.tr(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text('common.ok'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            // 2. Token kontrolü
                            final hasEnoughTokens =
                                await TokenService.spendQuizTokens();
                            if (!hasEnoughTokens) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'category_ui.insufficient_tokens'.tr()),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            debugPrint('Quiz başlatılıyor');

                            // Preload ad so it's ready for the first question

                            widget.onStartQuiz(
                              _selectedCategory!,
                              _selectedDifficulty!,
                              getDurationForDifficulty(_selectedDifficulty),
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(28),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 28,
                            color: isEnabled
                                ? const Color(0xFF667eea)
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'category_ui.start_quiz'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isEnabled
                                  ? const Color(0xFF667eea)
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isEnabled ? Colors.orange.withValues(alpha: 0.2) : Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '10',
                                  style: TextStyle(
                                    color: isEnabled ? Colors.orange : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.monetization_on_rounded,
                                  size: 16,
                                  color: isEnabled ? Colors.orange : Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  int _getTokenRewardForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Kolay':
        return 2;
      case 'Orta':
        return 3;
      case 'Zor':
        return 4;
      case 'Imkansız':
        return 6;
      default:
        return 3;
    }
  }
}

class DifficultyItem {
  final String name;
  final Color color;
  final IconData icon;
  final String descriptionKey;
  final int time;
  final String key;

  DifficultyItem(
    this.name,
    this.color,
    this.icon,
    this.descriptionKey,
    this.time,
    this.key,
  );
}
