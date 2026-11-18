import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/database_helper.dart';
import '../widgets/glass_container.dart';
import '../widgets/my_native_ad.dart';

/// Yanlışlarım: son 14 günde yanlış cevaplanan soruları, doğru cevaplarıyla birlikte gösterir.
/// Yalnızca [requiredTests] ve üzeri test çözmüş kullanıcılara açılır.
class WrongAnswersScreen extends StatefulWidget {
  const WrongAnswersScreen({super.key});

  static const int requiredTests = 5;

  @override
  State<WrongAnswersScreen> createState() => _WrongAnswersScreenState();
}

class _WrongAnswersScreenState extends State<WrongAnswersScreen> {
  late final Future<List<Question>> _questions =
      DatabaseHelper.instance.getWrongAnswerQuestions(limit: 40);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'wrong_review.title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<List<Question>>(
                  future: _questions,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF6366F1)));
                    }
                    final questions = snapshot.data ?? const <Question>[];
                    if (questions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'wrong_review.empty'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: questions.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Text(
                            'wrong_review.subtitle'.tr(),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13),
                          );
                        }
                        final qIdx = index - 1;
                        final card = _buildQuestionCard(questions[qIdx]);
                        final showAdAfter = (qIdx + 1) % 4 == 0 ||
                            (qIdx == questions.length - 1 && questions.length < 4);
                        if (!showAdAfter) return card;
                        return Column(
                          children: [
                            card,
                            const SizedBox(height: 12),
                            const MyNativeAd(height: 65),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    return GlassContainer(
      borderRadius: 18,
      opacity: 0.1,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.3),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: i == question.correctIndex
                      ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: i == question.correctIndex ? const Color(0xFF22C55E) : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        question.options[i],
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (i == question.correctIndex)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            'wrong_review.correct_answer'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
