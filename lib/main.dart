import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/welcome_screen.dart';
import 'screens/kategori_screen.dart';
import 'screens/quiz_screen.dart';
import 'models/test_result.dart';
import 'screens/loading_screen.dart';
import 'models/question.dart';
import 'services/ai_api_service.dart';
import 'services/database_helper.dart';
import 'screens/test_sonucu_screen.dart';
import 'widgets/my_native_ad.dart';
import 'services/notification_service.dart';
import 'services/update_control.dart';
import 'services/requestExactAlarmPermissionIfNeeded.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await NotificationPermissionManager.requestNotificationPermissionsSimple()
        .timeout(Duration(seconds: 5));
  } catch (_) {
    print("Bildirim izni istenemedi");
  }

  await NotificationService.init();
  // Uygulama başlarken veya ayarlar sayfasında
  await NotificationService.showDailyRewardNotification();
  await NotificationService.showAiQuestionReminderNotification(1);
  await NotificationService.showAiQuestionReminderNotification(2);

  // Paralel olarak dotenv ve reklam başlatma işlemleri
  await Future.wait([
    dotenv.load(),
    MobileAds.instance.initialize(),
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Oyunu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: QuizFlow(),
    );
  }
}

class QuizFlow extends StatefulWidget {
  final String? initialCategory;
  final String? initialDifficulty;
  final int? initialDuration;

  const QuizFlow({
    super.key,
    this.initialCategory,
    this.initialDifficulty,
    this.initialDuration,
  });

  @override
  State<QuizFlow> createState() => _QuizFlowState();
}

class _QuizFlowState extends State<QuizFlow> {
  final AiApiService _apiService = AiApiService();
  String? _screenState; // welcome, category, quiz, result
  String? _error;
  bool _loading = false;

  List<Question> _questions = [];
  List<int?> _userAnswers = [];
  String _selectedCategory = '';
  String _selectedDifficulty = '';
  int _score = 0;
  int _duration = 60;

  @override
  void initState() {
    super.initState();

    if (widget.initialCategory != null &&
        widget.initialDifficulty != null &&
        widget.initialDuration != null) {
      _startQuiz(
        widget.initialCategory!,
        widget.initialDifficulty!,
        widget.initialDuration!,
      );
    } else {
      _screenState = 'welcome';
    }
  }

  void _showCategoryScreen() {
    setState(() {
      _screenState = 'category';
    });
  }

  void _showQuizScreen() {
    setState(() {
      _screenState = 'quiz';
    });
  }

  Future<void> _startQuiz(
    String category,
    String difficulty,
    int duration,
  ) async {
    print('Quiz başlatılıyor: $category, $difficulty, $duration');

    setState(() {
      _loading = true;
      _screenState = 'quiz';
      _selectedCategory = category;
      _selectedDifficulty = difficulty;
      _duration = duration;
      _questions = [];
      _userAnswers = [];
      _score = 0;
      _error = null; // Önceki hataları temizle
    });

    try {
      print('API çağrısı yapılıyor...');
      final questions = await _apiService.fetchQuestions(
        category: category,
        difficulty: difficulty,
        count: 5,
      );
      print('API çağrısı başarılı, ${questions.length} soru alındı');

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
      print('State güncellendi, quiz başlayabilir');
    } catch (e) {
      print('API çağrısı hatası: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onQuizFinished({required List<int?> userAnswers, required int score}) {
    setState(() {
      _userAnswers = userAnswers;
      _score = score;
      _screenState = 'result';
    });
  }

  void _onRestartQuiz() {
    setState(() {
      _screenState = 'category';
      _questions = [];
      _userAnswers = [];
      _score = 0;
    });
  }

  void _onBackToWelcome() {
    setState(() {
      _screenState = 'welcome';
      _questions = [];
      _userAnswers = [];
      _score = 0;
      _selectedCategory = '';
      _selectedDifficulty = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return loading_screen();
    }
    switch (_screenState) {
      case 'welcome':
        return WelcomeScreen(onStart: _showCategoryScreen);
      case 'category':
        return KategoriScreen(
          onStartQuiz: _startQuiz,
          onStart: _showCategoryScreen,
        );
      case 'quiz':
        if (_questions.isEmpty) {
          return loading_screen();
        }
        return QuizScreen(
          questions: _questions,
          category: _selectedCategory,
          difficulty: _selectedDifficulty,
          duration: _duration,
          onFinished: (List<int?> userAnswers, int score) {
            _onQuizFinished(userAnswers: userAnswers, score: score);
          },
        );
      case 'result':
        return TestSonucuScreen(
          questions: _questions,
          userAnswers: _userAnswers,
          score: _score,
          onRestart: _onRestartQuiz,
          onBackToWelcome: _onBackToWelcome,
          difficulty: _selectedDifficulty,
        );
      default:
        return loading_screen();
    }
  }
}
