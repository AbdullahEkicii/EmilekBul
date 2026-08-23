import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/animated_splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/kategori_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/loading_screen.dart';
import 'models/question.dart';
import 'services/question_pool_service.dart';
import 'screens/test_sonucu_screen.dart';
import 'services/notification_service.dart';

import 'services/analytics_service.dart';
import 'services/user_service.dart';
import 'services/sound_service.dart';
import 'services/performance_service.dart';
import 'services/fullscreen_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FullScreenService.init();

  // Kritik başlatmaları paralel yap — main thread'i minimum blokla
  try {
    await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      dotenv.load(),
      EasyLocalization.ensureInitialized(),
      SoundService.init(),
      PerformanceService.init(),
    ]);

    // Analytics servisini başlat
    await AnalyticsService.init();
    
    // Firestore önbellek boyutunu 15 MB ile sınırla (Varsayılan 100 MB veri şişmesini önler)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 15 * 1024 * 1024,
    );

    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(), // Production provider
    );
  } catch (e) {
    debugPrint("Kritik başlatma hatası: $e");
  }

  // Arka planda başlasınlar, açılışı geciktirmesinler
  Future(() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint("MobileAds init error: $e");
    }
    NotificationService.init().catchError((e) => debugPrint("Notif init error: $e"));
  });

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
        Locale('ru'),
        Locale('ar'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('it'),
        Locale('pt'),
        Locale('ja'),
        Locale('ko'),
        Locale('zh'),
        Locale('hi'),
        Locale('id'),
        Locale('nl'),
        Locale('pl'),
        Locale('sv'),
        Locale('uk'),
        Locale('vi'),
        Locale('th'),
        Locale('cs'),
        Locale('el'),
        Locale('ro'),
        Locale('hu'),
        Locale('da'),
        Locale('fi'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Oyunu',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.observer],
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AnimatedSplashScreen(),
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
  String? _screenState; // welcome, category, quiz, result
  bool _loading = false;
  bool _isDataReady = false;

  List<Question> _questions = [];
  List<int?> _userAnswers = [];
  String _selectedCategory = '';
  String _selectedDifficulty = '';
  int _score = 0;
  int _duration = 60;
  bool _isOnboarding = false;
  int _currentQuestionCount = 5;
  bool _isDuel = false;
  int _botScore = 0;
  String _botName = 'Rakip';
  String _botAvatar = 'avatars/avatar_1.jpg';
  bool _playerFinishedFirst = false;

  @override
  void initState() {
    super.initState();

    // Bildirim izinlerini kontrol et ve planla (UI render olduktan sonra)
    // NOT: Artık bu işlem WelcomeScreen veya LoginRegisterScreen içinde yapılıyor
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkPermissions();
    // });

    if (widget.initialCategory != null &&
        widget.initialDifficulty != null &&
        widget.initialDuration != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Since we only pass these parameters for the forced initial quiz from WelcomeScreen,
        // it's safe to assume this is an onboarding flow.
        if (mounted) {
          setState(() {
            _isOnboarding = true;
          });
          _startQuiz(
            widget.initialCategory!,
            widget.initialDifficulty!,
            widget.initialDuration!,
          );
        }
      });
    } else {
      // Check if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Not logged in -> Auto Guest Login
        _autoLoginAndSetup();
      } else {
        // Logged in -> Go to Welcome (or standard flow)
        _screenState = 'welcome';
      }
    }
  }

  Future<void> _autoLoginAndSetup() async {
    setState(() {
      _loading = true; // Show loading screen while logging in
    });

    try {
      debugPrint("_autoLoginAndSetup: Starting Guest Login...");
      // 1. Auto Guest Login
      final userCredential = await UserService.signInAsGuest().timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint("_autoLoginAndSetup: Guest Login timeout after 10s");
        throw Exception("Guest Login Timeout");
      });
      debugPrint("_autoLoginAndSetup: Guest Login completed, userCredential: ${userCredential?.user?.uid}");

      if (userCredential != null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _screenState = 'welcome';
          });
        }
      } else {
        // Fallback if guest login fails (extremely rare)
        if (mounted) {
          setState(() {
            _loading = false;
            _screenState = 'welcome';
          });
        }
      }
    } catch (e) {
      debugPrint("_autoLoginAndSetup: Error caught: $e");
      if (mounted) {
        setState(() {
          _loading = false;
          _screenState = 'welcome';
        });
      }
    }
  }

  void _showCategoryScreen() {
    setState(() {
      _screenState = 'category';
    });
  }

  Future<void> _startQuiz(
    String category,
    String difficulty,
    int duration, {
    int count = 5,
    bool isDuel = false,
  }) async {
    debugPrint('Quiz başlatılıyor: $category, $difficulty, $duration, isDuel: $isDuel');
    final languageCode = context.locale.languageCode;

    AnalyticsService.logQuizStart(
      category: category,
      difficulty: difficulty,
      questionCount: count,
    );

    setState(() {
      _loading = true;
      _isDataReady = false;
      _screenState = 'quiz';
      _selectedCategory = category;
      _selectedDifficulty = difficulty;
      _duration = duration;
      _currentQuestionCount = count;
      _isDuel = isDuel;
      _questions = [];
      _userAnswers = [];
      _score = 0;
    });

    try {
      debugPrint('Hibrit soru havuzundan çekiliyor...');

      final questions = await QuestionPoolService.getHybridQuestions(
        category: category,
        difficulty: difficulty,
        languageCode: languageCode,
        count: count,
        includeSpacedRepetition: true,
      );

      debugPrint('Soru yükleme başarılı, ${questions.length} soru hazır');

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isDataReady = true;
      });
      debugPrint('Data hazır. Kullanıcı onayı bekleniyor.');
    } catch (e) {
      debugPrint('API çağrısı hatası: $e');
      
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_screenState != 'welcome' &&
            _screenState != 'category' &&
            _screenState != 'result') {
          _screenState = 'category';
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İnternet bağlantısı yok. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onQuizFinished({
    required List<int?> userAnswers,
    required int score,
    int? botScore,
    String? botName,
    String? botAvatar,
    bool? playerFinishedFirst,
  }) {
    // Doğru cevap sayısını hesapla
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (i < userAnswers.length &&
          userAnswers[i] != null &&
          userAnswers[i] == _questions[i].correctIndex) {
        correctCount++;
      }
    }

    final isWinner = _isDuel ? (score > (botScore ?? 0)) : false;

    AnalyticsService.logQuizCompleted(
      category: _selectedCategory,
      difficulty: _selectedDifficulty,
      score: score,
      correctAnswers: correctCount,
      totalQuestions: _questions.length,
      isDuel: _isDuel,
      isWinner: isWinner,
    );

    setState(() {
      _userAnswers = userAnswers;
      _score = score;
      _botScore = botScore ?? 0;
      _botName = botName ?? 'Rakip';
      _botAvatar = botAvatar ?? 'avatars/avatar_1.jpg';
      _playerFinishedFirst = playerFinishedFirst ?? false;
      _screenState = 'result';
    });
  }

  void _onRestartQuiz() {
    _isOnboarding = false;
    _startQuiz(
      _selectedCategory,
      _selectedDifficulty,
      _duration,
      count: _currentQuestionCount,
      isDuel: _isDuel,
    );
  }

  void _onContinueWithDifficulty(String difficulty) {
    _isOnboarding = false;
    _startQuiz(
      _selectedCategory,
      difficulty,
      _duration,
      count: _currentQuestionCount,
      isDuel: _isDuel,
    );
  }

  void _onBackToWelcome() {
    setState(() {
      _screenState = 'welcome';
      _questions = [];
      _userAnswers = [];
      _score = 0;
      _selectedCategory = '';
      _selectedDifficulty = '';
      _isOnboarding = false;
      _currentQuestionCount = 5;
    });
  }

  void _onStartQuizTransition() {
    setState(() {
      _loading = false;
      _isDataReady = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // If we are doing the initial guest login, just show a blank dark screen
      // so it seamlessly transitions from AnimatedSplashScreen without a 3rd splash
      if (_screenState == null) {
        return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
        );
      }
      return LoadingScreen(
        isDataReady: _isDataReady,
        onStart: _onStartQuizTransition,
      );
    }
    switch (_screenState) {
      case 'welcome':
        return WelcomeScreen(onStart: _showCategoryScreen, skipLoading: true);
      case 'category':
        return KategoriScreen(
          onStartQuiz: _startQuiz,
          onStart: _showCategoryScreen,
        );
      case 'quiz':
        if (_questions.isEmpty) {
          return LoadingScreen(
            isDataReady: _isDataReady,
            onStart: _onStartQuizTransition,
            onTimeout: () {
              if (!mounted) return;
              setState(() {
                _loading = false;
                _screenState = 'category';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('errors.no_internet_ai'.tr()),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          );
        }
        return QuizScreen(
          questions: _questions,
          category: _selectedCategory,
          difficulty: _selectedDifficulty,
          duration: _duration,
          isDuel: _isDuel,
          onFinished: (List<int?> userAnswers, int score, {int? botScore, String? botName, String? botAvatar, bool? playerFinishedFirst}) {
            _onQuizFinished(
              userAnswers: userAnswers,
              score: score,
              botScore: botScore,
              botName: botName,
              botAvatar: botAvatar,
              playerFinishedFirst: playerFinishedFirst,
            );
          },
        );
      case 'result':
        return TestSonucuScreen(
          questions: _questions,
          userAnswers: _userAnswers,
          score: _score,
          onRestart: _onRestartQuiz,
          onBackToWelcome: _onBackToWelcome,
          onContinueWithDifficulty: _onContinueWithDifficulty,
          difficulty: _selectedDifficulty,
          category: _selectedCategory,
          isOnboarding: _isOnboarding,
          isDuel: _isDuel,
          botScore: _botScore,
          botName: _botName,
          botAvatar: _botAvatar,
          playerFinishedFirst: _playerFinishedFirst,
        );
      default:
        // Default loading screen with no data ready if just initializing
        return const LoadingScreen();
    }
  }
}
