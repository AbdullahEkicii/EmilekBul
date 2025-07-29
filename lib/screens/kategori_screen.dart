import 'package:emilekbul/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emilekbul/screens/past_tests_screen.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:emilekbul/widgets/token_widget.dart';
import 'package:emilekbul/services/token_service.dart';

class KategoriScreen extends StatefulWidget {
  final Function(String category, String difficulty, int duration) onStartQuiz;
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

  // Kategori bilgilerini genişlettim
  final List<CategoryItem> _categories = [
    CategoryItem(
      'Genel Kültür',
      Icons.quiz,
      Color(0xFFFF6B6B),
      'Tarih, bilim, edebiyat',
      '5 soru',
    ),
    CategoryItem(
      'Sanat',
      Icons.palette,
      Color(0xFF4ECDC4),
      'Resim, müzik, heykel',
      '5 soru',
    ),
    CategoryItem(
      'Coğrafya',
      Icons.public,
      Color(0xFF45B7D1),
      'Ülkeler, başkentler, kıtalar',
      '5 soru',
    ),
    CategoryItem(
      'Futbol',
      Icons.sports_soccer,
      Color(0xFF96CEB4),
      'Takımlar, oyuncular',
      '5 soru',
    ),
    CategoryItem(
      'Dini',
      Icons.mosque,
      Color(0xFFFECA57),
      'İslam tarihi ve kültürü',
      '5 soru',
    ),
    CategoryItem(
      'Teknoloji',
      Icons.computer,
      Color(0xFF7B68EE),
      'Yazılım, donanım, internet',
      '5 soru',
    ),
  ];

  final List<DifficultyItem> _difficulties = [
    DifficultyItem(
      'Kolay-Orta',
      Color(0xFF96CEB4),
      Icons.sentiment_satisfied,
      'Kolay-Orta',
      '10 saniye',
    ),
    DifficultyItem(
      'Orta',
      Color(0xFFFECA57),
      Icons.sentiment_neutral,
      'Orta',
      '15 saniye',
    ),
    DifficultyItem(
      'Orta-Zor',
      Color(0xFFFF6B6B),
      Icons.sentiment_very_dissatisfied,
      'Orta-Zor',
      '20 saniye',
    ),
    DifficultyItem(
      'İmkansız',
      Color(0xFF22223B),
      Icons.warning_amber_rounded,
      'Aşırı zor',
      '25 saniye',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
    _cleanOldTests(); // ilk açılışta temizlik
  }

  void _cleanOldTests() async {
    try {
      await DatabaseHelper.instance.deleteOldTests(days: 14);
      print('Eski testler temizlendi.');
    } catch (e) {
      print('Temizleme hatası: $e');
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
    final RenderObject? renderObject =
        _difficultyKey.currentContext?.findRenderObject();
    if (renderObject != null) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent * 0.6,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
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
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                  Color(0xFFA67BFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    SizedBox(height: 40), // Home ikonuna yer bırak
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildCategorySection(),
                            const SizedBox(height: 32),
                            _buildDifficultySection(),
                            const SizedBox(height: 32),
                            _buildQuizPreview(),
                            const SizedBox(height: 32),
                            _buildActionButtons(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 14,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) =>
                        WelcomeScreen(onStart: widget.onStart),
                  ),
                  (route) => false,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 14,
            child: const TokenWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.quiz, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quiz Kategorisi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hangi konuda bilginizi test etmek istersiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category,
                  color: Colors.white.withOpacity(0.9),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Kategori Seçin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Seçilen: $_selectedCategory',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildCategoryGrid(),
          ],
        ),
      ),
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
        childAspectRatio: 1.2,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = _selectedCategory == category.name;

        return GestureDetector(
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
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected ? category.color : Colors.white.withOpacity(0.3),
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: category.color.withOpacity(0.3),
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
                        ? category.color.withOpacity(0.15)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    category.icon,
                    size: 28,
                    color: isSelected ? category.color : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? category.color : Colors.white,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? category.color.withOpacity(0.7)
                        : Colors.white.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDifficultySection() {
    return Container(
      key: _difficultyKey,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(
          _selectedCategory != null ? 0.12 : 0.06,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(
            _selectedCategory != null ? 0.3 : 0.15,
          ),
          width: 1,
        ),
        boxShadow: _selectedCategory != null
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up,
                color: Colors.white.withOpacity(
                  _selectedCategory != null ? 0.9 : 0.5,
                ),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Zorluk Seviyesi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(
                    _selectedCategory != null ? 1.0 : 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedCategory == null) ...[
            const SizedBox(height: 12),
            Text(
              'Önce bir kategori seçin',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildDifficultySelector(),
        ],
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
                          : Colors.white.withOpacity(isEnabled ? 0.15 : 0.05),
                      borderRadius:
                          BorderRadius.circular(16), // Radius'u azalttım
                      border: Border.all(
                        color: isSelected && isEnabled
                            ? difficulty.color
                            : Colors.white.withOpacity(isEnabled ? 0.3 : 0.1),
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
                              : Colors.white.withOpacity(isEnabled ? 0.8 : 0.3),
                        ),
                        const SizedBox(height: 6),
                        // Metni daha kompakt hale getir
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            difficulty.name,
                            style: TextStyle(
                              color: isSelected && isEnabled
                                  ? difficulty.color
                                  : Colors.white
                                      .withOpacity(isEnabled ? 0.8 : 0.3),
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
                            difficulty.timeInfo,
                            style: TextStyle(
                              color: isSelected && isEnabled
                                  ? difficulty.color.withOpacity(0.7)
                                  : Colors.white
                                      .withOpacity(isEnabled ? 0.5 : 0.2),
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

    final selectedCategoryItem = _categories.firstWhere(
      (cat) => cat.name == _selectedCategory,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: 1.0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quiz Önizleme',
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
                    'Kategori',
                    _selectedCategory!,
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.speed,
                    'Zorluk',
                    _selectedDifficulty!,
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.quiz,
                    'Soru Sayısı',
                    selectedCategoryItem.questionCount,
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
                    'Maliyet',
                    '10 Token',
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.card_giftcard,
                    'Doğru Cevap',
                    '${_getTokenRewardForDifficulty(_selectedDifficulty!)} Token',
                  ),
                ),
                Expanded(
                  child: _buildPreviewItem(
                    Icons.card_giftcard,
                    'Joker',
                    'Kullanım başına: 3-4-5 Token',
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
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final bool isEnabled =
        _selectedCategory != null && _selectedDifficulty != null;

    int getDurationForDifficulty(String? difficulty) {
      switch (difficulty) {
        case 'Kolay-Orta':
          return 10;
        case 'Orta':
          return 15;
        case 'Orta-Zor':
          return 20;
        case 'İmkansız':
          return 25;
        default:
          return 20;
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
                            color: Colors.white.withOpacity(0.3),
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
                            // Token kontrolü
                            final hasEnoughTokens =
                                await TokenService.spendQuizTokens();
                            if (!hasEnoughTokens) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '❌ Yetersiz token! Quiz başlatmak için 10 token gereklidir.'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }

                            print('Quiz başlatılıyor');
                            widget.onStartQuiz(
                              _selectedCategory!,
                              _selectedDifficulty!,
                              getDurationForDifficulty(_selectedDifficulty),
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
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
                            'Quiz\'e Başla',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isEnabled
                                  ? const Color(0xFF667eea)
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
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
      case 'Kolay-Orta':
      return 1;
      case 'Orta':
        return 2;
      case 'Orta-Zor':
        return 3;
      case 'İmkansız':
        return 4;
      default:
        return 2;
    }
  }

  int _getDurationForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Kolay-Orta':
        return 10;
      case 'Orta':
        return 15;
      case 'Orta-Zor':
        return 20;
      case 'İmkansız':
        return 25;
      default:
        return 20;
    }
  }
}

class CategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final String questionCount;

  CategoryItem(
    this.name,
    this.icon,
    this.color,
    this.description,
    this.questionCount,
  );
}

class DifficultyItem {
  final String name;
  final Color color;
  final IconData icon;
  final String description;
  final String timeInfo;

  DifficultyItem(
    this.name,
    this.color,
    this.icon,
    this.description,
    this.timeInfo,
  );
}
