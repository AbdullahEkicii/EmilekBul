import 'services/adaptive_service.dart';
import 'services/background_worker.dart';
import 'services/error_reporter.dart';
import 'services/haptic_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/ads_service.dart';
import 'services/interstitial_ad_manager.dart';
import 'widgets/rewarded_ad_manager.dart';
import 'theme/app_theme.dart';
import 'screens/animated_splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/quiz_screen.dart';
import 'screens/loading_screen.dart';
import 'models/question.dart';
import 'services/question_pool_service.dart';
import 'screens/test_sonucu_screen.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';

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
  final startupWatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  // Görsel önbelleğini sınırla (varsayılan 100 MB): düşük RAM'li cihazlarda bellek baskısını azaltır
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 150;
  await FullScreenService.init();

  // Kritik başlatmaları paralel yap — main thread'i minimum blokla
  try {
    await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      dotenv.load().catchError((_) {}),
      EasyLocalization.ensureInitialized(),
      PerformanceService.init(),
    ]);

    // Hata/çökme raporlama (Firebase hazır olduktan sonra)
    await ErrorReporter.init();

    // Firestore ayarları, Firestore'a ilk erişimden ÖNCE yapılmalı (sıra önemli).
    // Önbellek boyutunu 15 MB ile sınırla (Varsayılan 100 MB veri şişmesini önler)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 15 * 1024 * 1024,
    );

    // Ses ve Analytics ilk frame'i bloklamasın: arka planda başlat
    Future(() async {
      try {
        await SoundService.init();
        await HapticService.init();
        await BackgroundWorker.init();
      } catch (e) {
        debugPrint('SoundService init error: $e');
      }
      try {
        await AnalyticsService.init();
      } catch (e) {
        debugPrint('AnalyticsService init error: $e');
      }
    });

    // NOT: AppCheck bilerek beklenmeye devam ediyor. Arka plana alınırsa ilk
    // Firestore/Auth/Functions istekleri token'sız gidip (enforcement açıksa)
    // permission-denied/unauthenticated hatası verebilir.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(), // Production provider
      providerApple: const AppleDeviceCheckProvider(),
    );
  } catch (e) {
    debugPrint("Kritik başlatma hatası: $e");
  }

  // Arka planda başlasınlar, açılışı geciktirmesinler
  Future(() async {
    await AdsService.init();
    InterstitialAdManager.warmUp();
    RewardedAdManager.warmUp();
  });
  NotificationService.init().catchError((e) => debugPrint("Notif init error: $e"));
  PushNotificationService.init().catchError((e) => debugPrint("Push init error: $e"));

  debugPrint('Startup: runApp öncesi ${startupWatch.elapsedMilliseconds} ms');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ms = startupWatch.elapsedMilliseconds;
    debugPrint('Startup: ilk frame sonrası $ms ms');
    AnalyticsService.logAppStartup(ms);

    // İlk açılış önyükleme: UI'ı bloklamadan, hatalar sessiz
    const supported = {
      'en', 'tr', 'ru', 'ar', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'zh',
      'hi', 'id', 'nl', 'pl', 'sv', 'uk', 'vi', 'th', 'cs', 'el', 'ro', 'hu',
      'da', 'fi',
    };
    var lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (!supported.contains(lang)) lang = 'en';
    Future(() => QuestionPoolService.prefetchStarterQuestions(languageCode: lang))
        .catchError((e) => debugPrint('Starter prefetch error: $e'));
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
      theme: AppTheme.dark(),
      home: const AnimatedSplashScreen(),
    );
  }
}

class QuizFlow extends StatefulWidget {
  final String? initialCategory;
  final String? initialDifficulty;
  final int? initialDuration;
  final bool isOnboarding;
  final int initialTabIndex;

  const QuizFlow({
    super.key,
    this.initialCategory,
    this.initialDifficulty,
    this.initialDuration,
    this.isOnboarding = false,
    this.initialTabIndex = 0,
  });

  @override
  State<QuizFlow> createState() => _QuizFlowState();
}

class _QuizFlowState extends State<QuizFlow> {
  final GlobalKey<MainShellState> _mainShellKey = GlobalKey<MainShellState>();
  String? _screenState; // welcome, quiz, result
  late int _activeTabIndex;
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
    _activeTabIndex = widget.initialTabIndex.clamp(0, 3);

    // Bildirim izinlerini kontrol et ve planla (UI render olduktan sonra)
    // NOT: Artık bu işlem WelcomeScreen veya LoginRegisterScreen içinde yapılıyor
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkPermissions();
    // });

    if (widget.initialCategory != null &&
        widget.initialDifficulty != null &&
        widget.initialDuration != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isOnboarding = widget.isOnboarding;
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

    // Splash'ta giriş az önce başarısız olduysa ikinci kez bekletme: ana ekran arka planda yeniden dener
    final lastFail = UserService.lastGuestLoginFailure;
    if (lastFail != null && DateTime.now().difference(lastFail) < const Duration(seconds: 30)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _screenState = 'welcome';
        });
      }
      return;
    }

    try {
      debugPrint("_autoLoginAndSetup: Starting Guest Login...");
      // 1. Auto Guest Login
      final userCredential = await UserService.signInAsGuest().timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint("_autoLoginAndSetup: Guest Login timeout after 6s");
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
    AnalyticsService.logScreenView(screenName: 'quiz_flow_category');
    setState(() {
      _activeTabIndex = 1;
      _screenState = 'welcome';
    });
    _mainShellKey.currentState?.selectTab(1);
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

    AnalyticsService.logScreenView(screenName: 'quiz_flow_quiz');
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
      final loadWatch = Stopwatch()..start();

      var questions = await QuestionPoolService.getHybridQuestions(
        category: category,
        difficulty: difficulty,
        languageCode: languageCode,
        count: count,
        includeSpacedRepetition: true,
      );
      // Uyarlanabilir sıralama: kolaydan zora (yalnızca tekli test; küme aynı kalır)
      if (!isDuel) {
        questions = await AdaptiveService.arrange(questions, category: category, difficulty: difficulty);
      }

      debugPrint('Soru yükleme başarılı, ${questions.length} soru hazır');
      AnalyticsService.logQuestionsLoaded(
        category: category,
        latencyMs: loadWatch.elapsedMilliseconds,
        count: questions.length,
      );

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isDataReady = true;
      });
      debugPrint('Data hazır. Kullanıcı onayı bekleniyor.');
    } catch (e) {
      debugPrint('API çağrısı hatası: $e');
      AnalyticsService.logFirstSession('quiz_load_failed', {'category': category});
      ErrorReporter.record(e, null, reason: 'quiz_load');
      
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_screenState != 'welcome' && _screenState != 'result') {
          _activeTabIndex = 1;
          _screenState = 'welcome';
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('errors.no_internet_ai'.tr()),
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

    // Sonuç ekranından önce (uygunsa) geçiş reklamı
    InterstitialAdManager.onTestFinished(
      source: _isDuel ? 'duel' : 'solo',
      onDone: () {
        if (!mounted) return;
        setState(() {
          _userAnswers = userAnswers;
          _score = score;
          _botScore = botScore ?? 0;
          _botName = botName ?? 'Rakip';
          _botAvatar = botAvatar ?? 'avatars/avatar_1.jpg';
          _playerFinishedFirst = playerFinishedFirst ?? false;
          _screenState = 'result';
        });
      },
    );
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
      _activeTabIndex = 0;
      _screenState = 'welcome';
      _questions = [];
      _userAnswers = [];
      _score = 0;
      _selectedCategory = '';
      _selectedDifficulty = '';
      _isOnboarding = false;
      _currentQuestionCount = 5;
    });
    _mainShellKey.currentState?.selectTab(0);
  }

  void _onStartQuizTransition() {
    setState(() {
      _loading = false;
      _isDataReady = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    if (_loading) {
      // If we are doing the initial guest login, just show a blank dark screen
      // so it seamlessly transitions from AnimatedSplashScreen without a 3rd splash
      if (_screenState == null) {
        return const Scaffold(
          backgroundColor: AppColors.backgroundTop,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
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
        return MainShell(
          key: _mainShellKey,
          initialIndex: _activeTabIndex,
          onStart: _showCategoryScreen,
          onStartQuiz: _startQuiz,
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
                _activeTabIndex = 1;
                _screenState = 'welcome';
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
