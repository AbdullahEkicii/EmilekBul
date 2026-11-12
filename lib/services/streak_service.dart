import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import 'cloud_state_service.dart';
import 'notification_service.dart';
import 'token_service.dart';

enum FreezePurchaseResult { success, maxReached, insufficientTokens }

class StreakService {
  static const String _streakCountKey = 'user_login_streak_count';
  static const String _lastLoginDateKey = 'user_last_login_date';
  static const String _lastClaimedStreakDateKey = 'user_last_claimed_streak_date';
  static const String _freezeCountKey = 'user_streak_freezes';
  static const String _lastQuizDayKey = 'streak_last_quiz_day';

  static const List<int> streakRewards = [20, 40, 60, 80, 120, 180, 300];
  static const int freezePrice = 150;
  static const int maxFreezes = 3;

  // Seri kurtarma
  static const int rescueTokenPrice = 200;
  static const int rescueMaxMissedDays = 7;
  static const int rescueMaxMissedDaysForAd = 3;
  static const String _rescueStreakKey = 'streak_rescue_streak';
  static const String _rescueMissedKey = 'streak_rescue_missed';
  static const String _rescueDayKey = 'streak_rescue_day';
  static const String _rescueShownDayKey = 'streak_rescue_shown_day';

  static String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Mevcut streak ve bugün ödül alınıp alınmadığını döner.
  /// Kaçırılan günler dondurma hakkıyla karşılanabiliyorsa seri korunur.
  static Future<Map<String, dynamic>> checkStreakStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastLoginStr = prefs.getString(_lastLoginDateKey);
    final String? lastClaimedStr = prefs.getString(_lastClaimedStreakDateKey);
    int currentStreak = prefs.getInt(_streakCountKey) ?? 0;
    int freezes = prefs.getInt(_freezeCountKey) ?? 0;
    int freezesUsed = 0;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    if (lastLoginStr != null) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final lastLoginDate = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
      final differenceInDays = todayDate.difference(lastLoginDate).inDays;

      if (differenceInDays > 1) {
        final missedDays = differenceInDays - 1;
        if (currentStreak > 0 && freezes >= missedDays) {
          freezesUsed = missedDays;
          freezes -= missedDays;
          await prefs.setInt(_freezeCountKey, freezes);
          final yesterday = todayDate.subtract(const Duration(days: 1));
          await prefs.setString(_lastLoginDateKey, yesterday.toIso8601String());
          AnalyticsService.logStreakFreezeUsed(count: missedDays);
          await _saveToCloud();
        } else {
          // Seri kurtarma teklifi için kaybedilen seriyi bugüne özel kaydet
          if (currentStreak > 0 && missedDays <= rescueMaxMissedDays) {
            await prefs.setInt(_rescueStreakKey, currentStreak);
            await prefs.setInt(_rescueMissedKey, missedDays);
            await prefs.setString(_rescueDayKey, _dateKey(now));
          }
          currentStreak = 0;
          await prefs.setInt(_streakCountKey, 0);
        }
      }
    } else {
      currentStreak = 0;
    }

    final bool canClaimToday = lastClaimedStr != _dateKey(now);
    final bool playedToday = prefs.getString(_lastQuizDayKey) == _dateKey(now);
    NotificationService.scheduleStreakReminder(streak: currentStreak, claimedToday: !canClaimToday);

    return {
      'streak': currentStreak,
      'canClaimToday': canClaimToday,
      'playedToday': playedToday,
      'todayReward': streakRewards[currentStreak % streakRewards.length],
      'freezes': freezes,
      'freezesUsed': freezesUsed,
    };
  }

  /// Kilometre taşı bonusları: tam bu seri günlerine ulaşınca BİR KEZ verilir (gün -> jeton).
  static const Map<int, int> milestoneBonuses = {7: 50, 14: 100, 30: 200, 60: 400, 100: 800};

  /// Son talepte kazanılan kilometre taşı bonusu/serisi (arayüz kutlaması için; okununca sıfırlanır)
  static int lastMilestoneBonus = 0;
  static int lastMilestoneStreak = 0;

  /// Bugünkü streak ödülünü al
  static Future<int> claimStreakReward() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await checkStreakStatus();

    // Streak ödülü için bugün en az bir test (tekli, düello veya Günün Testi) çözülmüş olmalı
    if (status['canClaimToday'] != true || status['playedToday'] != true) {
      return 0;
    }

    final int currentStreak = (status['streak'] as int) + 1;
    final now = DateTime.now();
    final int rewardAmount = streakRewards[(currentStreak - 1) % streakRewards.length];

    await prefs.setInt(_streakCountKey, currentStreak);
    await prefs.setString(_lastLoginDateKey, now.toIso8601String());
    await prefs.setString(_lastClaimedStreakDateKey, _dateKey(now));

    await TokenService.addTokens(rewardAmount, source: 'streak');
    AnalyticsService.logStreakClaimed(streak: currentStreak, reward: rewardAmount);

    // Kilometre taşı: seri tam bu güne ulaştıysa ek bonus (yalnızca o gün, tek sefer)
    final bonus = milestoneBonuses[currentStreak] ?? 0;
    lastMilestoneBonus = bonus;
    lastMilestoneStreak = bonus > 0 ? currentStreak : 0;
    if (bonus > 0) {
      await TokenService.addTokens(bonus, source: 'streak_milestone');
      AnalyticsService.logCustomEvent(
          name: 'streak_milestone', parameters: {'streak': currentStreak, 'bonus': bonus});
    }

    await _saveToCloud();
    NotificationService.scheduleStreakReminder(streak: currentStreak, claimedToday: true);

    return rewardAmount + bonus;
  }

  /// Sadece streak sayısını getir
  static Future<int> getStreakCount() async {
    final status = await checkStreakStatus();
    return status['streak'] as int;
  }

  /// Bir test tamamlandığında çağrılır; bugünün streak ödülünü açar.
  static Future<void> markQuizPlayedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_lastQuizDayKey) == today) return;
    await prefs.setString(_lastQuizDayKey, today);
    await _saveToCloud();
  }

  static Future<int> getFreezeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_freezeCountKey) ?? 0;
  }

  static Future<FreezePurchaseResult> buyFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final freezes = prefs.getInt(_freezeCountKey) ?? 0;
    if (freezes >= maxFreezes) return FreezePurchaseResult.maxReached;

    final paid = await TokenService.spendTokens(freezePrice, reason: 'streak_freeze');
    if (!paid) return FreezePurchaseResult.insufficientTokens;

    await prefs.setInt(_freezeCountKey, freezes + 1);
    await _saveToCloud();
    return FreezePurchaseResult.success;
  }

  /// Ödül olarak dondurma hakkı verir. Limit doluysa false döner.
  static Future<bool> grantFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final freezes = prefs.getInt(_freezeCountKey) ?? 0;
    if (freezes >= maxFreezes) return false;
    await prefs.setInt(_freezeCountKey, freezes + 1);
    await _saveToCloud();
    return true;
  }

  // ---- Seri kurtarma (kaybedilen seriyi aynı gün geri alma) ----

  /// Bugün kaybedilmiş bir seri varsa ve teklif henüz gösterilmediyse
  /// {'streak': kaybedilen seri, 'missed': kaçırılan gün} döner.
  static Future<Map<String, int>?> getPendingRescueOffer() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_rescueDayKey) != today) return null;
    if (prefs.getString(_rescueShownDayKey) == today) return null;
    final streak = prefs.getInt(_rescueStreakKey) ?? 0;
    final missed = prefs.getInt(_rescueMissedKey) ?? 0;
    if (streak <= 0 || missed <= 0) return null;
    return {'streak': streak, 'missed': missed};
  }

  /// Teklif bugün gösterildi olarak işaretlenir (günde bir kez).
  static Future<void> markRescueOfferShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rescueShownDayKey, _dateKey(DateTime.now()));
  }

  /// Kaybedilen seriyi geri yükler. [viaTokens] true ise jeton düşer, aksi halde
  /// çağıran taraf ödüllü reklamı izletmiş olmalıdır (en fazla [rescueMaxMissedDaysForAd] gün).
  static Future<bool> rescueStreak({required bool viaTokens}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dateKey(now);
    if (prefs.getString(_rescueDayKey) != today) return false;
    final streak = prefs.getInt(_rescueStreakKey) ?? 0;
    final missed = prefs.getInt(_rescueMissedKey) ?? 0;
    if (streak <= 0 || (prefs.getInt(_streakCountKey) ?? 0) > 0) return false;
    if (!viaTokens && missed > rescueMaxMissedDaysForAd) return false;

    if (viaTokens) {
      final paid = await TokenService.spendTokens(rescueTokenPrice, reason: 'streak_rescue');
      if (!paid) return false;
    }

    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    await prefs.setInt(_streakCountKey, streak);
    await prefs.setString(_lastLoginDateKey, yesterday.toIso8601String());
    await prefs.remove(_rescueDayKey);
    await prefs.remove(_rescueStreakKey);
    await prefs.remove(_rescueMissedKey);
    AnalyticsService.logStreakRescued(streak: streak, method: viaTokens ? 'tokens' : 'ad');
    await _saveToCloud();
    return true;
  }

  /// Yarın alınacak seri ödülünün tahmini (bugün oynandıysa bugünkü ödül alınacağı varsayılır).
  static Future<int> getNextDayRewardEstimate() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_streakCountKey) ?? 0;
    final claimedToday = prefs.getString(_lastClaimedStreakDateKey) == _dateKey(DateTime.now());
    final streakAfterToday = claimedToday ? streak : streak + 1;
    return streakRewards[streakAfterToday % streakRewards.length];
  }

  static Future<void> _saveToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    await CloudStateService.save('streak', {
      'count': prefs.getInt(_streakCountKey) ?? 0,
      'lastLogin': prefs.getString(_lastLoginDateKey),
      'lastClaimed': prefs.getString(_lastClaimedStreakDateKey),
      'freezes': prefs.getInt(_freezeCountKey) ?? 0,
      'lastQuizDay': prefs.getString(_lastQuizDayKey),
    });
  }

  /// Buluttaki durum yereldekinden eski değilse yereli onunla değiştirir.
  static Future<void> importState(Map<String, dynamic> cloud) async {
    final String? cloudClaimed = cloud['lastClaimed'] as String?;
    if (cloudClaimed == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String? localClaimed = prefs.getString(_lastClaimedStreakDateKey);
    if (localClaimed != null && localClaimed.compareTo(cloudClaimed) > 0) return;

    await prefs.setInt(_streakCountKey, (cloud['count'] as num?)?.toInt() ?? 0);
    await prefs.setString(_lastClaimedStreakDateKey, cloudClaimed);
    final String? cloudLastLogin = cloud['lastLogin'] as String?;
    if (cloudLastLogin != null) {
      await prefs.setString(_lastLoginDateKey, cloudLastLogin);
    }
    await prefs.setInt(_freezeCountKey, (cloud['freezes'] as num?)?.toInt() ?? 0);
    final String? cloudQuizDay = cloud['lastQuizDay'] as String?;
    if (cloudQuizDay != null) await prefs.setString(_lastQuizDayKey, cloudQuizDay);
  }
}
