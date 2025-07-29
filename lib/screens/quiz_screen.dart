import 'package:emilekbul/models/question.dart';
import 'package:emilekbul/models/test_result.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:emilekbul/services/token_service.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/token_widget.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class QuizScreen extends StatefulWidget {
  final List<Question> questions; // 5'li paket
  final String category;
  final String difficulty;
  final int duration; // saniye cinsinden süre
  final void Function(List<int?> userAnswers, int score) onFinished;

  const QuizScreen({
    super.key,
    required this.questions,
    required this.category,
    required this.difficulty,
    required this.duration,
    required this.onFinished,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0; // hangi sorudayız
  int? _selectedIndex; // şu anki soruda seçilen şık
  late List<int?> _userAnswers; // tüm cevaplar
  late AnimationController _animationController;
  late List<Animation<double>> _optionAnimations;
  late int _remainingSeconds;
  Timer? _timer;
  int _jokerCount = 0; // Kullanılan joker sayısı
  final List<int> _eliminatedOptions = []; // Eleme uygulanan seçenekler
  bool _testFinished = false; // Test bitip bitmediğini kontrol etmek için

  @override
  void initState() {
    super.initState();
    _userAnswers = List.filled(widget.questions.length, null);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _setupOptionAnimations();
    _animationController.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = widget.duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _onTimeExpired();
      }
    });
  }

  void _onTimeExpired() {
    if (_userAnswers[_currentIndex] == null) {
      _userAnswers[_currentIndex] = null; // Cevaplanmadı
    }
    _goNext();
  }

  void _setupOptionAnimations() {
    final optionsLength = widget.questions[_currentIndex].options.length;
    _optionAnimations = List.generate(optionsLength, (index) {
      final startTime = 0.2 * index;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            startTime.clamp(0.0, 1.0),
            1.0,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _useJoker() async {
    // Joker başına düşecek token miktarını hesapla
    int tokenCost = 0;
    switch (_jokerCount) {
      case 0: // İlk joker
        tokenCost = 3;
        break;
      case 1: // İkinci joker
        tokenCost = 4;
        break;
      default: // Üçüncü ve sonrası
        tokenCost = 5;
        break;
    }

    // Token yeterli mi kontrol et
    final currentTokens = await TokenService.getTokenAmount();
    if (currentTokens < tokenCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Yeterli tokeniniz yok! Joker için $tokenCost token gerekiyor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Token düş
    await TokenService.spendTokens(tokenCost);

    // Joker sayısını artır
    if (mounted) {
      setState(() {
        _jokerCount++;
      });
    }

    // Yanlış seçeneklerden birini rastgele seç ve elemeye ekle
    final currentQuestion = widget.questions[_currentIndex];
    final wrongOptions = <int>[];

    for (int i = 0; i < currentQuestion.options.length; i++) {
      if (i != currentQuestion.correctIndex &&
          !_eliminatedOptions.contains(i)) {
        wrongOptions.add(i);
      }
    }

    if (wrongOptions.isNotEmpty) {
      final randomIndex = wrongOptions[
          DateTime.now().millisecondsSinceEpoch % wrongOptions.length];
      setState(() {
        _eliminatedOptions.add(randomIndex);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir yanlış seçenek elendi!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Elemeye alınacak yanlış seçenek kalmadı!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _onOptionSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  int _getJokerTokenCost() {
    switch (_jokerCount) {
      case 0:
        return 3;
      case 1:
        return 4;
      default:
        return 5;
    }
  }

  void _goNext() {
    _timer?.cancel();
    if (_selectedIndex != null) {
      _userAnswers[_currentIndex] = _selectedIndex;
    } else if (_userAnswers[_currentIndex] == null) {
      _userAnswers[_currentIndex] = null; // Cevaplanmadı
    }
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _eliminatedOptions
            .clear(); // Yeni soruya geçerken elemeye uygulanan seçenekleri sıfırla
      });
      _animationController.reset();
      _setupOptionAnimations();
      _animationController.forward();
      _startTimer();
    } else {
      _finishTest();
    }
  }

  void _showFinishEarlyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Testi Bitir',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7F7CFF),
            ),
          ),
          content: Text(
            'Testi bitirmeden çıkmak istediğinizden emin misiniz? '
            '${_currentIndex + 1}. sorudasınız.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _finishTest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7F7CFF),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Evet, Bitir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishTest() async {
    if (_testFinished) return; // Eğer test zaten bitmişse tekrar işlem yapma

    setState(() {
      _testFinished = true;
    });

    int score = 0;
    int wrongAnswers = 0;

    // Doğru ve yanlış cevapları hesapla
    for (int i = 0; i < widget.questions.length; i++) {
      if (_userAnswers[i] == widget.questions[i].correctIndex) {
        score++;
      } else if (_userAnswers[i] != null) {
        // Sadece cevap verilmiş ama yanlışsa say
        wrongAnswers++;
      }
    }

    // Doğru cevaplar için token ekle
    await TokenService.awardTokensForQuiz(widget.difficulty, score);

    final testResult = TestResult(
      category: widget.category,
      difficulty: widget.difficulty,
      score: score,
      date: DateTime.now(),
      questions: widget.questions.asMap().entries.map((e) {
        final idx = e.key;
        final q = e.value;
        final user = _userAnswers[idx];
        return TestQuestionDetail(
          testId: 0,
          question: q.question,
          userAnswer: user != null ? q.options[user] : 'Cevaplanmadı',
          correctAnswer: q.options[q.correctIndex],
          options: q.options,
        );
      }).toList(),
    );
    await DatabaseHelper.instance.createTest(testResult);
    widget.onFinished(_userAnswers, score);
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          children: [
            // Soru sayacı - sola yaslanmış
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Soru ${_currentIndex + 1} / ${widget.questions.length}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF7F7CFF),
        elevation: 0,
        automaticallyImplyLeading: false, // Geri tuşunu kaldır
        actions: [
          // Token Widget
          Container(
            key: ValueKey('token_$_jokerCount'),
            child: const TokenWidget(),
          ),
          const SizedBox(width: 12),

          // Bitir butonu - profesyonel stil
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: () => _showFinishEarlyDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size(0, 0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stop_circle_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Bitir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7F7CFF), Color(0xFFA67BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kalan süre ve joker butonu
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '$_remainingSeconds sn',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Joker butonu
                        GestureDetector(
                          onTap: _useJoker,
                          child: Column(
                            children: [
                              // Token cost indicator
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.monetization_on,
                                      color: Colors.amber[700],
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${_getJokerTokenCost()}',
                                      style: TextStyle(
                                        color: Colors.amber[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 4),
                              // Main joker button
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber[400]!,
                                      Colors.amber[600]!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lightbulb,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'JOKER',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Soru metni
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        currentQuestion.question,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Seçenekler
                    ...List.generate(currentQuestion.options.length, (index) {
                      // Eleme uygulanmış seçenekleri gizle
                      if (_eliminatedOptions.contains(index)) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.red.withOpacity(0.5), width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.close, color: Colors.red, size: 24),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  currentQuestion.options[index],
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final isSelected = _selectedIndex == index;
                      return GestureDetector(
                        onTap: () => _onOptionSelected(index),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.85)
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(
                                        0.18,
                                      ),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepPurple
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.deepPurple
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.deepPurple
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  currentQuestion.options[index],
                                  style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Onayla butonu
                    GestureDetector(
                      onTap: _selectedIndex != null ? _goNext : null,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 250),
                        width: double.infinity,
                        height: 60,
                        margin: EdgeInsets.only(top: 16, bottom: 8),
                        decoration: BoxDecoration(
                          gradient: _selectedIndex != null
                              ? LinearGradient(
                                  colors: [
                                    Color(0xFF5E35B1), // Daha koyu mor
                                    Color(0xFF7E57C2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Color.fromARGB(
                                      255,
                                      234,
                                      234,
                                      234,
                                    ), // Daha koyu gri
                                    Color(0xFFE0E0E0),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: _selectedIndex != null
                              ? [
                                  BoxShadow(
                                    color: Color(0xFF7E57C2).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Onayla',
                            style: TextStyle(
                              color: _selectedIndex != null
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // MyNativeAd(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
