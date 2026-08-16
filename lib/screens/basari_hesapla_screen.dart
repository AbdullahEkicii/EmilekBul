import 'package:flutter/material.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:emilekbul/screens/welcome_screen.dart';
import 'package:emilekbul/screens/past_tests_screen.dart';
import '../widgets/my_native_ad.dart';
import 'package:emilekbul/widgets/glass_container.dart';
import 'package:emilekbul/widgets/navigation_buttons.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_categories.dart';

class BasariHesaplaScreen extends StatefulWidget {
  final VoidCallback onStart;
  const BasariHesaplaScreen({super.key, required this.onStart});

  @override
  State<BasariHesaplaScreen> createState() => _BasariHesaplaScreenState();
}

class _BasariHesaplaScreenState extends State<BasariHesaplaScreen>
    with TickerProviderStateMixin {
  Map<String, Map<String, int>> _categoryStats = {};
  bool _loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _orbController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStats());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await DatabaseHelper.instance.getCategoryStatsFromTests();
      if (mounted) {
        setState(() {
          _categoryStats = stats;
          _loading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('stats.error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBackgroundOrbs() {
    return AnimatedBuilder(
      animation: _orbAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: 100 + (20 * _orbAnimation.value),
              left: -30,
              child: _buildOrb(200, const Color(0xFF667eea).withValues(alpha: 0.2)),
            ),
            Positioned(
              bottom: 150 - (30 * _orbAnimation.value),
              right: -50,
              child: _buildOrb(250, const Color(0xFF764ba2).withValues(alpha: 0.15)),
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
          BoxShadow(color: color, blurRadius: 60, spreadRadius: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Deep Gradient Background
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
          RepaintBoundary(child: _buildBackgroundOrbs()),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    children: [
                      AppHomeButton(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'stats.title'.tr(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'stats.subtitle'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? _buildLoadingState()
                      : _categoryStats.isEmpty
                          ? _buildEmptyState()
                          : _buildStatsList(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: MyNativeAd(
                    height: 120,
                    factoryId: 'adFactoryExample',
                    refreshInterval: 30,
                  ),
                ),
                const SizedBox(height: 5),
                _buildFooterButton(),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: GlassContainer(
        useBlur: false,
        opacity: 0.12,
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'stats.loading'.tr(),
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GlassContainer(
        useBlur: false,
        opacity: 0.12,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
            Text(
              'stats.empty_title'.tr(),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'stats.empty_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _categoryStats.length,
        itemBuilder: (context, index) {
          final entry = _categoryStats.entries.elementAt(index);
          return _buildCategoryCard(entry, index);
        },
      ),
    );
  }

  Widget _buildCategoryCard(
      MapEntry<String, Map<String, int>> entry, int index) {
    final category = _getLocalizedCategoryName(entry.key);
    final correct = entry.value['correct'] ?? 0;
    final wrong = entry.value['wrong'] ?? 0;
    final total = correct + wrong;
    final successRate = total > 0 ? (correct / total) : 0.0;
    final color = _getSuccessColor(successRate);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GlassContainer(
        useBlur: false,
        opacity: 0.08,
        borderRadius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.auto_graph_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getSuccessMessage(successRate),
                        style: TextStyle(
                            fontSize: 13,
                            color: color.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(successRate * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900, color: color),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress Bar
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(5)),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutQuart,
                  height: 10,
                  width: (MediaQuery.of(context).size.width - 88) * successRate,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.4),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatLabel(
                    'stats.label_correct'.tr(), '$correct', Colors.greenAccent),
                _buildStatLabel(
                    'stats.label_wrong'.tr(), '$wrong', Colors.redAccent),
                _buildStatLabel(
                    'stats.label_total'.tr(), '$total', Colors.blueAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatLabel(String label, String value, Color color) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text('$value $label',
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildFooterButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PastTestsScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.analytics_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'stats.view_details'.tr(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getSuccessColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981);
    if (rate >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getSuccessMessage(double rate) {
    if (rate >= 0.8) return 'stats.level_great'.tr();
    if (rate >= 0.5) return 'stats.level_good'.tr();
    return 'stats.level_bad'.tr();
  }

  String _getLocalizedCategoryName(String dbCategoryName) {
    if (dbCategoryName == 'Genel') return 'categories.general'.tr();
    final key = AppCategories.getCategoryKey(dbCategoryName);
    return key.isNotEmpty ? key.tr() : dbCategoryName;
  }
}
