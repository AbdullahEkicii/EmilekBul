import 'package:flutter/material.dart';
import '../models/question.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/token_widget.dart';
import '../services/token_service.dart';

class TestSonucuScreen extends StatefulWidget {
  final List<Question> questions;
  final List<int?> userAnswers;
  final int score;
  final VoidCallback onRestart;
  final VoidCallback onBackToWelcome;
  final String difficulty;

  const TestSonucuScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.score,
    required this.onRestart,
    required this.onBackToWelcome,
    required this.difficulty,
  });

  @override
  State<TestSonucuScreen> createState() => _TestSonucuScreenState();
}

class _TestSonucuScreenState extends State<TestSonucuScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    // Token ödülü ver
    _awardTokens();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _awardTokens() async {
    // Quiz sonucuna göre token ver
    await TokenService.awardTokensForQuiz(
      widget.difficulty,
      widget.score,
    );

    // Token ödülü bildirimi
    if (widget.score > 0) {
      final tokensPerAnswer =
          TokenService.getTokensForCorrectAnswer(widget.difficulty);
      final totalTokens = widget.score * tokensPerAnswer;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 $totalTokens token kazandınız!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final successRate = (widget.score / widget.questions.length) * 100;
    final correctAnswers = widget.score;
    final wrongAnswers = widget.questions.length - widget.score;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C63FF), Color(0xFF9C88FF), Color(0xFFE6E6FA)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                _buildHeader(context),

                // Stats Section
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildStatsSection(
                    successRate,
                    correctAnswers,
                    wrongAnswers,
                  ),
                ),

                const SizedBox(height: 8),

                // Results List - Ana içerik alanı
                Expanded(child: _buildResultsList()),
                //Container(
                //  margin: const EdgeInsets.symmetric(horizontal: 20),
                //  child: MyNativeAd(),
                //),

                // Action Buttons - En altta sabit
                _buildActionButtons(),
                // Native Ad - Stats section ile Results list arasına eklendi
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      // <- Notch ve status bar'dan otomatik korur
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Test Sonucu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const TokenWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    double successRate,
    int correctAnswers,
    int wrongAnswers,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Score Circle - Biraz küçültüldü
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: successRate >= 70
                    ? [const Color(0xFF6C63FF), const Color(0xFF9C88FF)]
                    : [Colors.red.shade400, Colors.red.shade600],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (successRate >= 70 ? const Color(0xFF6C63FF) : Colors.red)
                          .withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${successRate.toInt()}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${widget.score}/${widget.questions.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Result Message
          Text(
            _getResultMessage(successRate),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: successRate >= 70
                  ? const Color(0xFF6C63FF)
                  : Colors.red.shade600,
            ),
          ),

          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Doğru',
                  value: correctAnswers.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: 'Yanlış',
                  value: wrongAnswers.toString(),
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: 'Başarı',
                  value: '${successRate.toInt()}%',
                  icon: Icons.trending_up,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header - Daha küçük
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.quiz, color: const Color(0xFF6C63FF), size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Soru Detayları',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.questions.length} Soru',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF6C63FF).withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content - Daha erişilebilir
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: widget.questions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final q = widget.questions[index];
                final userAnswerIdx = widget.userAnswers.length > index
                    ? widget.userAnswers[index]
                    : null;
                final userAnswer = userAnswerIdx != null
                    ? q.options[userAnswerIdx]
                    : 'Cevaplanmadı';
                final correctAnswer = q.options[q.correctIndex];
                final isCorrect = userAnswer == correctAnswer;

                return Container(
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withOpacity(0.05)
                        : Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      childrenPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        q.question,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Question
                              Container(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Soru:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      q.question,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Answers
                              _buildAnswerRow(
                                'Sizin Cevabınız:',
                                userAnswer,
                                isCorrect ? Colors.green : Colors.red,
                              ),
                              const SizedBox(height: 6),
                              _buildAnswerRow(
                                'Doğru Cevap:',
                                correctAnswer,
                                Colors.green,
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildAnswerRow(String label, String answer, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            answer,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: widget.onRestart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Tekrar Dene',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: widget.onBackToWelcome,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                side: const BorderSide(color: Color(0xFF6C63FF), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Ana Ekrana Dön',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getResultMessage(double successRate) {
    if (successRate >= 90) {
      return 'Mükemmel! 🎉';
    } else if (successRate >= 80) {
      return 'Çok İyi! 👏';
    } else if (successRate >= 60) {
      return 'Ortalama! 👍';
    } else if (successRate >= 40) {
      return 'Sallamasyon! 🤔';
    } else {
      return 'Eyvah Eyvah! ';
    }
  }
}
