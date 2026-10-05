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

  /// Başlangıç ayarları
  static Future<void> init() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
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

  /// Tekli Quiz Başlatma Eventi
  static Future<void> logQuizStart({
    required String category,
    required String difficulty,
    int questionCount = 5,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'quiz_start',
        parameters: {
          'category': category,
          'difficulty': difficulty,
          'question_count': questionCount,
        },
      );
    } catch (e) {
      debugPrint('Analytics logQuizStart error: $e');
    }
  }

  /// 1v1 Düello Maçı Başlatma Eventi
  static Future<void> logDuelMatchStart({
    required String category,
    required String difficulty,
    required int betTokens,
    required int questionCount,
    required bool isHost,
    required bool isWithBot,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'duel_match_start',
        parameters: {
          'category': category,
          'difficulty': difficulty,
          'bet_tokens': betTokens,
          'question_count': questionCount,
          'is_host': isHost ? 1 : 0,
          'is_with_bot': isWithBot ? 1 : 0,
        },
      );
    } catch (e) {
      debugPrint('Analytics logDuelMatchStart error: $e');
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

  static Future<void> logTokenEarned({required int amount, required String source}) =>
      logCustomEvent(name: 'token_earned', parameters: {'amount': amount, 'source': source});

  static Future<void> logTokenSpent({required int amount, required String reason}) =>
      logCustomEvent(name: 'token_spent', parameters: {'amount': amount, 'reason': reason});

  static Future<void> logShopPurchase({required String category, required String itemId, required int price}) =>
      logCustomEvent(name: 'shop_purchase', parameters: {'category': category, 'item_id': itemId, 'price': price});

  static Future<void> logQuestCompleted({required String questId, required int reward}) =>
      logCustomEvent(name: 'quest_claimed', parameters: {'quest_id': questId, 'reward': reward});

  static Future<void> logStreakClaimed({required int streak, required int reward}) =>
      logCustomEvent(name: 'streak_claimed', parameters: {'streak': streak, 'reward': reward});

  static Future<void> logStreakRescueOffered({required int streak, required int missed}) =>
      logCustomEvent(name: 'streak_rescue_offered', parameters: {'streak': streak, 'missed': missed});

  static Future<void> logStreakRescued({required int streak, required String method}) =>
      logCustomEvent(name: 'streak_rescued', parameters: {'streak': streak, 'method': method});

  static Future<void> logStreakFreezeUsed({required int count}) =>
      logCustomEvent(name: 'streak_freeze_used', parameters: {'count': count});

  static Future<void> logWheelSpin({required String prize, required bool isAdSpin}) =>
      logCustomEvent(name: 'wheel_spin', parameters: {'prize': prize, 'is_ad_spin': isAdSpin ? 1 : 0});

  static Future<void> logReferralRedeemed() => logCustomEvent(name: 'referral_redeemed');

  static Future<void> logAchievementUnlocked({required String achievementId}) =>
      logCustomEvent(name: 'achievement_unlocked', parameters: {'achievement_id': achievementId});

  static Future<void> logShare({required String contentType}) async {
    try {
      await _analytics.logShare(contentType: contentType, itemId: contentType, method: 'system_share');
    } catch (e) {
      debugPrint('Analytics logShare error: $e');
    }
  }

  static Future<void> logAdImpression({required String format, required String placement}) =>
      logCustomEvent(name: 'ad_impression_app', parameters: {'ad_format': format, 'placement': placement});

  static Future<void> logDuelFunnel(String step, {Map<String, Object>? parameters}) =>
      logCustomEvent(name: 'duel_$step', parameters: parameters);

  static Future<void> logNotificationPermission({required String result, required String trigger}) =>
      logCustomEvent(name: 'notif_permission', parameters: {'result': result, 'trigger': trigger});

  static Future<void> logNotificationOpen({required String type}) =>
      logCustomEvent(name: 'notification_open', parameters: {'type': type});

  static Future<void> logQuestionsLoaded({required String category, required int latencyMs, required int count}) =>
      logCustomEvent(name: 'questions_loaded', parameters: {'category': category, 'latency_ms': latencyMs, 'count': count});

  static Future<void> logQuizAbandoned({required String category, required int answered, required int total}) =>
      logCustomEvent(name: 'quiz_abandoned', parameters: {'category': category, 'answered': answered, 'total': total});

  /// Açılış süresi (main başlangıcından ilk frame'e, ms)
  static Future<void> logAppStartup(int ms) =>
      logCustomEvent(name: 'app_startup', parameters: {'duration_ms': ms});

  static Future<void> logDuelChallengeSent() => logCustomEvent(name: 'duel_challenge_sent');

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
