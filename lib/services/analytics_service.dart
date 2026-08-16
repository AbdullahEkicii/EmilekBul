import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics servis yöneticisi
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Firebase Analytics instance'ına erişim
  static FirebaseAnalytics get analytics => _analytics;

  /// NavigatorObserver: Otomatik ekran geçişlerini izler
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Başlangıç ayarları ve ilk açılış logu
  static Future<void> init() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      await logAppOpen();
    } catch (e) {
      debugPrint('Analytics init error: $e');
    }
  }

  /// Kullanıcı ID'sini Analytics'e bağlama
  static Future<void> setUserId(String? uid) async {
    try {
      await _analytics.setUserId(id: uid);
    } catch (e) {
      debugPrint('Analytics setUserId error: $e');
    }
  }

  /// Kullanıcı özelliği (User Property) belirleme
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics setUserProperty error: $e');
    }
  }

  /// Uygulama açılış eventi
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      debugPrint('Analytics logAppOpen error: $e');
    }
  }

  /// Giriş eventi (Guest, Google, Play Games, Email)
  static Future<void> logLogin({required String loginMethod}) async {
    try {
      await _analytics.logLogin(loginMethod: loginMethod);
      await _analytics.setUserProperty(name: 'user_type', value: loginMethod);
    } catch (e) {
      debugPrint('Analytics logLogin error: $e');
    }
  }

  /// Kayıt olma eventi
  static Future<void> logSignUp({required String signUpMethod}) async {
    try {
      await _analytics.logSignUp(signUpMethod: signUpMethod);
      await _analytics.setUserProperty(name: 'user_type', value: signUpMethod);
    } catch (e) {
      debugPrint('Analytics logSignUp error: $e');
    }
  }

  /// Quiz Başlatma Eventi
  static Future<void> logQuizStart({
    required String category,
    required String difficulty,
    bool isDuel = false,
    int questionCount = 5,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'quiz_start',
        parameters: {
          'category': category,
          'difficulty': difficulty,
          'is_duel': isDuel ? 1 : 0,
          'question_count': questionCount,
        },
      );
    } catch (e) {
      debugPrint('Analytics logQuizStart error: $e');
    }
  }

  /// Quiz Tamamlama Eventi
  static Future<void> logQuizCompleted({
    required String category,
    required String difficulty,
    required int score,
    required int correctAnswers,
    required int totalQuestions,
    bool isDuel = false,
    bool isWinner = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'quiz_completed',
        parameters: {
          'category': category,
          'difficulty': difficulty,
          'score': score,
          'correct_answers': correctAnswers,
          'total_questions': totalQuestions,
          'is_duel': isDuel ? 1 : 0,
          'is_winner': isWinner ? 1 : 0,
          'accuracy_rate': totalQuestions > 0
              ? ((correctAnswers / totalQuestions) * 100).round()
              : 0,
        },
      );
    } catch (e) {
      debugPrint('Analytics logQuizCompleted error: $e');
    }
  }

  /// Ekran Görüntüleme Eventi
  static Future<void> logScreenView({required String screenName}) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics logScreenView error: $e');
    }
  }

  /// Özel Event Kaydı
  static Future<void> logCustomEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics logCustomEvent ($name) error: $e');
    }
  }
}
