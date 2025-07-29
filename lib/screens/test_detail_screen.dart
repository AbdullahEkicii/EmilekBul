import 'package:emilekbul/models/test_result.dart';
import 'package:flutter/material.dart';
import '../widgets/my_native_ad.dart';

class TestDetailScreen extends StatelessWidget {
  final TestResult test;

  const TestDetailScreen({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    // Sonuçları hesapla
    int correct = 0;
    for (var question in test.questions) {
      if (question.userAnswer == question.correctAnswer) correct++;
    }
    int wrong = test.questions.length - correct;
    double successRate = (correct / test.questions.length) * 100;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section - Küçültüldü
              Container(
                padding: EdgeInsets.all(20), // 24'ten 20'ye düşürüldü
                child: Column(
                  children: [
                    // Back Button ve Title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '${test.category} Test Detayı',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16), // 24'ten 16'ya düşürüldü

                    // Test Icon ve Bilgi - Küçültüldü
                    Icon(
                      Icons.quiz,
                      size: 36, // 48'den 36'ya düşürüldü
                      color: Colors.white.withOpacity(0.9),
                    ),
                    SizedBox(height: 8), // 12'den 8'e düşürüldü
                    Text(
                      'Test Analizi',
                      style: TextStyle(
                        fontSize: 20, // 24'ten 20'ye düşürüldü
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6), // 8'den 6'ya düşürüldü
                    Text(
                      'Tüm sorularınızı detaylı olarak inceleyin',
                      style: TextStyle(
                        fontSize: 13, // 14'ten 13'e düşürüldü
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats Cards
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Doğru',
                        value: correct.toString(),
                        icon: Icons.check_circle,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Yanlış',
                        value: wrong.toString(),
                        icon: Icons.cancel,
                        color: Color(0xFFFF5722),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Başarı',
                        value: '${successRate.toInt()}%',
                        icon: Icons.trending_up,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16), // 24'ten 16'ya düşürüldü

              // Questions List
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(24), // Yuvarlak şekil eklendi
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.format_list_numbered,
                              color: Color(0xFF667eea),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Sorular ve Cevaplar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: test.questions.length,
                          itemBuilder: (context, index) {
                            final question = test.questions[index];
                            final isCorrect =
                                question.userAnswer == question.correctAnswer;

                            return Container(
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCorrect
                                      ? Color(0xFF4CAF50).withOpacity(0.3)
                                      : Color(0xFFFF5722).withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Question Header
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isCorrect
                                                ? Color(0xFF4CAF50)
                                                : Color(0xFFFF5722),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                isCorrect
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: isCorrect
                                                    ? Color(0xFF4CAF50)
                                                    : Color(0xFFFF5722),
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                isCorrect ? 'Doğru' : 'Yanlış',
                                                style: TextStyle(
                                                  color: isCorrect
                                                      ? Color(0xFF4CAF50)
                                                      : Color(0xFFFF5722),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),

                                    // Question Text
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.help_outline,
                                                color: Color(0xFF667eea),
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Soru',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF4A5568),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            question.question,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2D3748),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16),

                                    // Answers Section
                                    Column(
                                      children: [
                                        // User Answer
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isCorrect
                                                ? Color(
                                                    0xFF4CAF50,
                                                  ).withOpacity(0.1)
                                                : Color(
                                                    0xFFFF5722,
                                                  ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: isCorrect
                                                  ? Color(
                                                      0xFF4CAF50,
                                                    ).withOpacity(0.3)
                                                  : Color(
                                                      0xFFFF5722,
                                                    ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    color: isCorrect
                                                        ? Color(0xFF4CAF50)
                                                        : Color(0xFFFF5722),
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      'Sizin Cevabınız',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF4A5568,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                question.userAnswer,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: isCorrect
                                                      ? Color(0xFF4CAF50)
                                                      : Color(0xFFFF5722),
                                                ),
                                                maxLines: null,
                                                overflow: TextOverflow.visible,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Correct Answer (sadece yanlış ise göster)
                                        if (!isCorrect) ...[
                                          SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Color(
                                                0xFF4CAF50,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Color(
                                                  0xFF4CAF50,
                                                ).withOpacity(0.3),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.lightbulb,
                                                      color: Color(0xFF4CAF50),
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        'Doğru Cevap',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF4A5568,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  question.correctAnswer,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF4CAF50),
                                                  ),
                                                  maxLines: null,
                                                  overflow:
                                                      TextOverflow.visible,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
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
                ),
              ),

              // Native Ad eklendi
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: MyNativeAd(),
              ),
            ],
          ),
        ),
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
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
