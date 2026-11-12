import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'token_service.dart';

/// Sosyal kazançlar: paylaşım ödülü (günde bir kez).
/// Not: Paylaşım menüsünün gerçekten tamamlanıp tamamlanmadığı platformda doğrulanamaz;
/// ödül, paylaşım menüsü açıldığında verilir ve günde bir kezle sınırlıdır.
class SocialRewards {
  static const int shareTokens = 10;
  static const String _dayKey = 'share_reward_day';

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  /// Bugün paylaşım ödülü alınmadıysa jetonu verir ve kazanılan miktarı döner (alınmadıysa 0).
  static Future<int> claimShareReward(String contentType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _today();
      if (prefs.getString(_dayKey) == today) return 0;
      await prefs.setString(_dayKey, today);
      await TokenService.addTokens(shareTokens, source: 'share');
      AnalyticsService.logCustomEvent(
          name: 'share_reward', parameters: {'content': contentType, 'tokens': shareTokens});
      return shareTokens;
    } catch (_) {
      return 0;
    }
  }
}
