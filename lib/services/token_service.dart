import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import 'cloud_state_service.dart';
import 'retention_scheduler.dart';
import 'token_economy.dart';
import 'token_arena_rules.dart';
import 'user_service.dart';

class TokenService {
  static const String _tokenKey = 'user_tokens';
  static const String _lastDailyRewardKey = 'last_daily_reward';
  static const int _dailyRewardAmount = TokenEconomy.dailyRewardAmount;
  static const int _quizCost = TokenEconomy.quizEntryCost;
  static int get quizCost => _quizCost;

  // Günlük ücretsiz test hakkı (giriş ücreti alınmaz)
  static const int freeQuizzesPerDay = 3;
  static const String _freeDateKey = 'free_quiz_date';
  static const String _freeUsedKey = 'free_quiz_used';
  static const int _duelCost = TokenEconomy.duelEntryCost;
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

  // Günlük reklam hedefi: 3 ödüllü reklam izleyene bonus
  static const String _adDayKey = 'ad_goal_day';
  static const String _adCountKey = 'ad_goal_count';
  static const String _adClaimedDayKey = 'ad_goal_claimed_day';

  /// Bir ödüllü reklam izlendiğinde günlük hedef sayacını artırır
  static Future<void> recordRewardedAdForGoal() async {
    final prefs = await _getPrefs();
    final today = _today();
    final count = prefs.getString(_adDayKey) == today
        ? (prefs.getInt(_adCountKey) ?? 0)
        : 0;
    await prefs.setString(_adDayKey, today);
    await prefs.setInt(_adCountKey, count + 1);
  }

  /// Bugünkü reklam hedefinin durumu
  static Future<({int watched, bool claimed, bool ready})> adGoalStatus() async {
    final prefs = await _getPrefs();
    final today = _today();
    final watched = prefs.getString(_adDayKey) == today
        ? (prefs.getInt(_adCountKey) ?? 0)
        : 0;
    final claimed = prefs.getString(_adClaimedDayKey) == today;
    return (
      watched: watched,
      claimed: claimed,
      ready: TokenEconomy.adGoalReady(watchedToday: watched, claimedToday: claimed),
    );
  }

  /// Hedef tamamlandıysa bonusu verir. Bonus verildiyse true döner.
  static Future<bool> claimAdDailyGoal() async {
    final status = await adGoalStatus();
    if (!status.ready) return false;
    final prefs = await _getPrefs();
    await prefs.setString(_adClaimedDayKey, _today());
    await addTokens(TokenEconomy.adGoalBonus, source: 'ad_goal');
    return true;
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

  // Geri dönüş penceresinde 2 katına çıkan kazanım kaynakları (düello bahis ödülleri kasıtlı olarak dışarıda)
  static const Set<String> _comebackDoubledSources = {'quiz', 'daily_reward'};

  // Token ekle
  static Future<void> addTokens(int amount, {String source = 'other'}) async {
    var gained = amount;
    if (amount > 0 && _comebackDoubledSources.contains(source) && await _isComebackActive()) {
      gained = amount * 2;
    }
    final currentTokens = await getTokenAmount();
    await updateTokenAmount(currentTokens + gained);
    if (gained > 0) AnalyticsService.logTokenEarned(amount: gained, source: source);
  }

  static Future<bool> _isComebackActive() async {
    final prefs = await _getPrefs();
    final until = prefs.getInt(RetentionScheduler.kComebackUntil) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
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

  static String _today() {
    final n = DateTime.now();
    return "${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
  }

  /// Bugün kalan ücretsiz test hakkı
  static Future<int> freeQuizzesLeft() async {
    final prefs = await _getPrefs();
    if (prefs.getString(_freeDateKey) != _today()) return freeQuizzesPerDay;
    return (freeQuizzesPerDay - (prefs.getInt(_freeUsedKey) ?? 0))
        .clamp(0, freeQuizzesPerDay);
  }

  /// Test girişi: önce günlük ücretsiz hak, yoksa jeton düşer. Yetersizse false.
  static Future<bool> spendQuizTokens() async {
    final left = await freeQuizzesLeft();
    if (left > 0) {
      final prefs = await _getPrefs();
      final today = _today();
      final used = prefs.getString(_freeDateKey) == today
          ? (prefs.getInt(_freeUsedKey) ?? 0)
          : 0;
      await prefs.setString(_freeDateKey, today);
      await prefs.setInt(_freeUsedKey, used + 1);
      await CloudStateService.save('freeQuizzes', {'date': today, 'used': used + 1});
      AnalyticsService.logFreeQuizUsed(left: left - 1);
      return true;
    }
    final paid = await spendTokens(_quizCost, reason: 'quiz_entry');
    if (!paid) {
      AnalyticsService.logTokenWallHit(
          tokens: await getTokenAmount(), cost: _quizCost, source: 'quiz_entry');
    }
    return paid;
  }

  /// Aynı gün için buluttaki kullanım yereldekinden fazlaysa onu uygular (yeniden kurulum istismarını önler).
  static Future<void> importFreeQuizState(Map<String, dynamic> cloud) async {
    final date = cloud['date'] as String?;
    if (date == null || date != _today()) return;
    final cloudUsed = (cloud['used'] as num?)?.toInt() ?? 0;
    final prefs = await _getPrefs();
    final localUsed = prefs.getString(_freeDateKey) == date
        ? (prefs.getInt(_freeUsedKey) ?? 0)
        : 0;
    if (cloudUsed > localUsed) {
      await prefs.setString(_freeDateKey, date);
      await prefs.setInt(_freeUsedKey, cloudUsed);
    }
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

  // Çevrimdışı quiz tamamlanınca sabit ödül (doğru sayısından bağımsız)
  static Future<int> awardOfflineQuizReward({bool weeklyBonus = false}) async {
    final reward = weeklyBonus
        ? TokenEconomy.offlineQuizReward * TokenEconomy.offlineWeeklyMultiplier
        : TokenEconomy.offlineQuizReward;
    await addTokens(reward, source: weeklyBonus ? 'quiz_weekly_bonus' : 'quiz');
    return reward;
  }

  // Token Arena mini oyunları: bahis düşer, kazanılırsa çarpanlı geri ödeme yapılır
  static Future<bool> stakeMiniGame(String gameId) async {
    return spendTokens(TokenEconomy.miniGameStake, reason: 'mini_$gameId');
  }

  static Future<void> payMiniGame(String gameId) async {
    await addTokens(TokenArenaRules.payout(TokenEconomy.miniGameStake),
        source: 'mini_${gameId}_win');
  }
}
