import 'package:emilekbul/models/test_result.dart';
import 'package:emilekbul/screens/test_detail_screen.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:flutter/material.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/glass_container.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_categories.dart';

class PastTestsScreen extends StatefulWidget {
  const PastTestsScreen({super.key});

  @override
  State<PastTestsScreen> createState() => _PastTestsScreenState();
}

class _PastTestsScreenState extends State<PastTestsScreen>
    with TickerProviderStateMixin {
  late Future<List<TestResult>> _tests;
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  @override
  void initState() {
    super.initState();
    _tests = DatabaseHelper.instance.getAllTests();

    _orbController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat(reverse: true);

    _orbAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Widget _buildBackgroundOrbs() {
    return AnimatedBuilder(
      animation: _orbAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -50,
              right: -30 + (20 * _orbAnimation.value),
              child: _buildOrb(200, const Color(0xFF6366F1).withValues(alpha: 0.2)),
            ),
            Positioned(
              bottom: 100 + (40 * _orbAnimation.value),
              left: -40,
              child: _buildOrb(250, const Color(0xFFA855F7).withValues(alpha: 0.15)),
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
          BoxShadow(color: color, blurRadius: 80, spreadRadius: 20),
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
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
          ),
          RepaintBoundary(child: _buildBackgroundOrbs()),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: FutureBuilder<List<TestResult>>(
                    future: _tests,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      } else if (snapshot.hasError) {
                        return _buildErrorState(snapshot.error.toString());
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyState();
                      }

                      final tests = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        physics: const BouncingScrollPhysics(),
                        itemCount: tests.length,
                        itemBuilder: (context, index) {
                          return _buildTestCard(tests[index]);
                        },
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: MyNativeAd(
                    height: 100,
                    factoryId: 'adFactoryExample',
                    refreshInterval: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: GlassContainer(
                  borderRadius: 12,
                  opacity: 0.1,
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'past_tests.title'.tr(),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5),
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                    () => _tests = DatabaseHelper.instance.getAllTests()),
                child: GlassContainer(
                  borderRadius: 12,
                  opacity: 0.1,
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(TestResult test) {
    int correct = 0;
    for (var question in test.questions) {
      if (question.userAnswer == question.correctAnswer) correct++;
    }
    double successRate = (correct / test.questions.length) * 100;
    Color color = _getSuccessColor(successRate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        useBlur: false,
        opacity: 0.08,
        borderRadius: 28,
        padding: const EdgeInsets.all(24),
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => TestDetailScreen(test: test))),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.4)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(_getCategoryIcon(test.category),
                        color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _translateCategory(test.category),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            GlassContainer(
                              useBlur: false,
                              borderRadius: 8,
                              opacity: 0.1,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                _translateDifficulty(test.difficulty),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _getDifficultyColor(test.difficulty)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd.MM.yyyy').format(test.date),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white38),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(Icons.quiz_rounded, '${test.questions.length}',
                      'past_tests.question_count'.tr()),
                  _buildMiniStat(Icons.check_circle_rounded, '$correct',
                      'past_tests.correct_count'.tr(),
                      color: Colors.greenAccent),
                  _buildMiniStat(Icons.stars_rounded, '${successRate.toInt()}%',
                      'past_tests.success_rate'.tr(),
                      color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label,
      {Color color = Colors.white70}) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.6), size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child:
          CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 3),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          Text('past_tests.empty'.tr(),
              style: const TextStyle(color: Colors.white60, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
        child: Text(error, style: const TextStyle(color: Colors.redAccent)));
  }

  Color _getSuccessColor(double rate) {
    if (rate >= 80) return const Color(0xFF10B981);
    if (rate >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'kolay':
        return const Color(0xFF10B981);
      case 'orta':
        return const Color(0xFF3B82F6);
      case 'zor':
        return const Color(0xFFEF4444);
      default:
        return Colors.white70;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'matematik':
        return Icons.calculate_rounded;
      case 'fen':
        return Icons.science_rounded;
      case 'tarih':
        return Icons.history_edu_rounded;
      case 'türkçe':
        return Icons.menu_book_rounded;
      default:
        return Icons.quiz_rounded;
    }
  }

  String _translateDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Kolay':
        return 'category_ui.difficulty.easy'.tr();
      case 'Orta':
        return 'category_ui.difficulty.medium'.tr();
      case 'Zor':
        return 'category_ui.difficulty.hard'.tr();
      case 'Imkansız':
        return 'category_ui.difficulty.impossible'.tr();
      default:
        return difficulty;
    }
  }

  String _translateCategory(String categoryName) {
    try {
      final category = AppCategories.categories.firstWhere(
        (c) => c.name == categoryName,
      );
      return category.key.tr();
    } catch (_) {
      return categoryName;
    }
  }
}
