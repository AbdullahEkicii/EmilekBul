import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class TokenService {
  static const String _tokenKey = 'user_tokens';
  static const String _lastDailyRewardKey = 'last_daily_reward';
  static const int _dailyRewardAmount = 50;
  static const int _quizCost = 10;
  static const int _duelCost = 20;
  static const int _duelReward = 40;

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
  static Future<void> addTokens(int amount) async {
    final currentTokens = await getTokenAmount();
    await updateTokenAmount(currentTokens + amount);
  }

  // Token çıkar
  static Future<bool> spendTokens(int amount) async {
    final currentTokens = await getTokenAmount();
    if (currentTokens >= amount) {
      await updateTokenAmount(currentTokens - amount);
      return true;
    }
    return false;
  }

  // Quiz için token harca
  static Future<bool> spendQuizTokens() async {
    return await spendTokens(_quizCost);
  }

  // Düello için token harca
  static Future<bool> spendDuelTokens() async {
    return await spendTokens(_duelCost);
  }

  // Düello galibiyeti için token ver
  static Future<void> awardTokensForDuelWin() async {
    await addTokens(_duelReward);
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
    await addTokens(_dailyRewardAmount);
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
    await addTokens(totalTokens);
  }
}
