import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import 'user_service.dart';

class TokenService {
  static const String _tokenKey = 'user_tokens';
  static const String _lastDailyRewardKey = 'last_daily_reward';
  static const int _dailyRewardAmount = 50;
  static const int _quizCost = 10;
  static const int _duelCost = 20;
  static const int _duelReward = 40;

  // Jeton Güçlendirici: sonraki N testte test jeton ödülü 2 katına çıkar
  static const String _boosterKey = 'token_booster_remaining';
  static const int boosterPrice = 300;
  static const int boosterTests = 3;

  // SharedPreferences instance'ı için cache
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Token miktarını al
  static Future<int> getTokenAmount() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_tokenKey) ?? 0;
  }

  // Token miktarını güncelle
  static Future<void> updateTokenAmount(int amount) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_tokenKey, amount);
    // Firestore'u da güncelle (TokenWidget reactivity için)
    await UserService.updateUserTokens(amount);
  }

  // Token ekle
  static Future<void> addTokens(int amount, {String source = 'other'}) async {
    final currentTokens = await getTokenAmount();
    await updateTokenAmount(currentTokens + amount);
    if (amount > 0) AnalyticsService.logTokenEarned(amount: amount, source: source);
  }

  // Token çıkar
  static Future<bool> spendTokens(int amount, {String reason = 'other'}) async {
    final currentTokens = await getTokenAmount();
    if (currentTokens >= amount) {
      await updateTokenAmount(currentTokens - amount);
      if (amount > 0) AnalyticsService.logTokenSpent(amount: amount, reason: reason);
      return true;
    }
    return false;
  }

  static Future<int> getBoosterRemaining() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_boosterKey) ?? 0;
  }

  /// Güçlendirici satın alır. Zaten aktifse veya jeton yetmezse false döner.
  static Future<bool> buyBooster() async {
    final prefs = await _getPrefs();
    if ((prefs.getInt(_boosterKey) ?? 0) > 0) return false;
    final paid = await spendTokens(boosterPrice, reason: 'token_booster');
    if (!paid) return false;
    await prefs.setInt(_boosterKey, boosterTests);
    return true;
  }

  /// Aktif güçlendirici varsa ekstra ödülü verir ve bir hak düşer. Verilen ekstra miktarı döner.
  static Future<int> applyBooster(int baseReward) async {
    if (baseReward <= 0) return 0;
    final prefs = await _getPrefs();
    final remaining = prefs.getInt(_boosterKey) ?? 0;
    if (remaining <= 0) return 0;
    await prefs.setInt(_boosterKey, remaining - 1);
    await addTokens(baseReward, source: 'token_booster');
    return baseReward;
  }

  // Quiz için token harca
  static Future<bool> spendQuizTokens() async {
    return await spendTokens(_quizCost, reason: 'quiz_entry');
  }

  // Düello için token harca
  static Future<bool> spendDuelTokens() async {
    return await spendTokens(_duelCost, reason: 'duel_entry');
  }

  // Düello galibiyeti için token ver
  static Future<void> awardTokensForDuelWin() async {
    await addTokens(_duelReward, source: 'duel_win');
  }

  // Günlük ödül kontrolü
  static Future<bool> canClaimDailyReward() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRewardString = prefs.getString(_lastDailyRewardKey);

    if (lastRewardString == null) {
      return true;
    }

    final lastReward = DateTime.parse(lastRewardString);
    final now = DateTime.now();

    // Gece 12'de sıfırlama kontrolü
    final today = DateTime(now.year, now.month, now.day);
    final lastRewardDay =
        DateTime(lastReward.year, lastReward.month, lastReward.day);

    return today.isAfter(lastRewardDay);
  }

  // Günlük ödülü ver
  static Future<bool> claimDailyReward() async {
    if (!await canClaimDailyReward()) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastDailyRewardKey, DateTime.now().toIso8601String());
    await addTokens(_dailyRewardAmount, source: 'daily_reward');
    return true;
  }

  // Zorluk seviyesine göre token kazanma
  static int getTokensForCorrectAnswer(String difficulty) {
    switch (difficulty) {
      case 'Kolay':
        return 2;
      case 'Orta':
        return 3;
      case 'Zor':
        return 4;
      case 'Imkansız':
        return 6;
      default:
        return 3;
    }
  }

  // Quiz sonucuna göre token ver
  static Future<void> awardTokensForQuiz(
      String difficulty, int correctAnswers) async {
    final tokensPerAnswer = getTokensForCorrectAnswer(difficulty);
    final totalTokens = correctAnswers * tokensPerAnswer;
    await addTokens(totalTokens, source: 'quiz');
  }
}
