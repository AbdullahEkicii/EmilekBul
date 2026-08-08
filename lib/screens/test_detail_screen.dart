import 'package:emilekbul/models/test_result.dart';
import 'package:flutter/material.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/glass_container.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_categories.dart';

class TestDetailScreen extends StatefulWidget {
  final TestResult test;

  const TestDetailScreen({super.key, required this.test});

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      duration: const Duration(seconds: 15),
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
              child: _buildOrb(200, const Color(0xFF6366F1).withValues(alpha: 0.15)),
            ),
            Positioned(
              bottom: 150 + (40 * _orbAnimation.value),
              left: -40,
              child: _buildOrb(250, const Color(0xFFA855F7).withValues(alpha: 0.12)),
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
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 10)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int correct = 0;
    for (var question in widget.test.questions) {
      if (question.userAnswer == question.correctAnswer) correct++;
    }
    int wrong = widget.test.questions.length - correct;
    double successRate = (correct / widget.test.questions.length) * 100;

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
                _buildStatsSummary(correct, wrong, successRate),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    itemCount: widget.test.questions.length,
                    itemBuilder: (context, index) {
                      return _buildQuestionDetailCard(
                          widget.test.questions[index], index);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: MyNativeAd(
                    height: 120,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_translateCategory(widget.test.category)} | ${_translateDifficulty(widget.test.difficulty)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
                Text(
                  'past_tests.details_title'.tr(),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(int c, int w, double rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildMiniStat(
              'past_tests.correct_count'.tr(), '$c', Colors.greenAccent),
          const SizedBox(width: 12),
          _buildMiniStat('past_tests.wrong_count'.tr(), '$w', Colors.redAccent),
          const SizedBox(width: 12),
          _buildMiniStat('past_tests.success_rate'.tr(), '${rate.toInt()}%',
              Colors.indigoAccent),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionDetailCard(TestQuestionDetail question, int index) {
    final bool isCorrect = question.userAnswer == question.correctAnswer;
    final color = isCorrect ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GlassContainer(
        useBlur: false,
        opacity: 0.08,
        borderRadius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text('${index + 1}',
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Text(
                  isCorrect
                      ? 'past_tests.correct_answer_label'.tr()
                      : 'past_tests.wrong_answer_label'.tr(),
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                ),
                const Spacer(),
                Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: color.withValues(alpha: 0.5),
                    size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              question.question,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildAnswerBox('past_tests.your_answer'.tr(), question.userAnswer,
                isCorrect ? Colors.greenAccent : Colors.redAccent),
            if (!isCorrect) ...[
              const SizedBox(height: 12),
              _buildAnswerBox('past_tests.correct_answer'.tr(),
                  question.correctAnswer, Colors.greenAccent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerBox(String label, String answer, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(answer,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
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
}
