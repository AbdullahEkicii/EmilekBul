import 'package:emilekbul/models/test_result.dart';
import 'package:emilekbul/screens/test_detail_screen.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PastTestsScreen extends StatefulWidget {
  const PastTestsScreen({super.key});

  @override
  _PastTestsScreenState createState() => _PastTestsScreenState();
}

class _PastTestsScreenState extends State<PastTestsScreen> {
  late Future<List<TestResult>> _tests;

  @override
  void initState() {
    super.initState();
    _tests = DatabaseHelper.instance.getAllTests();
  }

  @override
  Widget build(BuildContext context) {
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
              // Header Section
              Container(
                padding: EdgeInsets.all(24),
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
                            'Geçmiş Testlerim',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Refresh Button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _tests = DatabaseHelper.instance.getAllTests();
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Header Icon ve Açıklama
                    Icon(
                      Icons.history,
                      size: 48,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Test Geçmişiniz',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Önceki test sonuçlarınızı inceleyin',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Tests List Container
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
                              Icons.quiz,
                              color: Color(0xFF667eea),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Test Listesi',
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
                        child: FutureBuilder<List<TestResult>>(
                          future: _tests,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _buildLoadingState();
                            } else if (snapshot.hasError) {
                              return _buildErrorState(
                                snapshot.error.toString(),
                              );
                            } else if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return _buildEmptyState();
                            }

                            final tests = snapshot.data!;
                            return ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              itemCount: tests.length,
                              itemBuilder: (context, index) {
                                final test = tests[index];
                                return _buildTestCard(test, index);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestCard(TestResult test, int index) {
    // Başarı oranını hesapla
    int correct = 0;
    for (var question in test.questions) {
      if (question.userAnswer == question.correctAnswer) correct++;
    }
    double successRate = (correct / test.questions.length) * 100;

    // Zorluk seviyesine göre renk
    Color difficultyColor = _getDifficultyColor(test.difficulty);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TestDetailScreen(test: test)),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: difficultyColor.withOpacity(0.3), width: 2),
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
            children: [
              // Header Row
              Row(
                children: [
                  // Test Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _getCategoryIcon(test.category),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),

                  // Test Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          test.category,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: difficultyColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: difficultyColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                test.difficulty,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: difficultyColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Color(0xFF718096),
                            ),
                            SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(test.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF718096),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow Icon
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF718096),
                    size: 16,
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.quiz,
                      label: 'Soru Sayısı',
                      value: '${test.questions.length}',
                      color: Color(0xFF667eea),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.check_circle,
                      label: 'Doğru',
                      value: '$correct',
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.trending_up,
                      label: 'Başarı',
                      value: '${successRate.toInt()}%',
                      color: successRate >= 70
                          ? Color(0xFF4CAF50)
                          : successRate >= 50
                          ? Color(0xFF2196F3)
                          : Color(0xFFFF5722),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF718096),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: CircularProgressIndicator(
              color: Color(0xFF667eea),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Testler yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFFF5722).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFFF5722),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Bir hata oluştu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.quiz_outlined,
              size: 48,
              color: Color(0xFF667eea),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Henüz test yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'İlk testinizi çözdüğünüzde burada görünecek',
            style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'kolay':
        return Color(0xFF4CAF50);
      case 'orta':
        return Color(0xFF2196F3);
      case 'zor':
        return Color(0xFFFF5722);
      default:
        return Color(0xFF667eea);
    }
  }

  IconData _getCategoryIcon(String category) {
    // Kategori ismine göre ikon döndür
    switch (category.toLowerCase()) {
      case 'matematik':
        return Icons.calculate;
      case 'fen':
      case 'fizik':
      case 'kimya':
      case 'biyoloji':
        return Icons.science;
      case 'tarih':
        return Icons.history_edu;
      case 'coğrafya':
        return Icons.public;
      case 'türkçe':
      case 'edebiyat':
        return Icons.menu_book;
      case 'İngilizce':
        return Icons.language;
      default:
        return Icons.quiz;
    }
  }
}
