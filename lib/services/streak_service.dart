import 'package:shared_preferences/shared_preferences.dart';
import 'token_service.dart';

class StreakService {
  static const String _streakCountKey = 'user_login_streak_count';
  static const String _lastLoginDateKey = 'user_last_login_date';
  static const String _lastClaimedStreakDateKey = 'user_last_claimed_streak_date';

  static const List<int> streakRewards = [20, 40, 60, 80, 120, 180, 300];

  /// Mevcut streak ve bugün ödül alınıp alınmadığını döner
  static Future<Map<String, dynamic>> checkStreakStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastLoginStr = prefs.getString(_lastLoginDateKey);
    final String? lastClaimedStr = prefs.getString(_lastClaimedStreakDateKey);
    int currentStreak = prefs.getInt(_streakCountKey) ?? 0;

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    bool canClaimToday = true;

    if (lastLoginStr != null) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final todayDate = DateTime(now.year, now.month, now.day);
      final lastLoginDate = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
      final differenceInDays = todayDate.difference(lastLoginDate).inDays;

      if (differenceInDays == 1) {
        // Dün girmiş, streak devam ediyor
      } else if (differenceInDays > 1) {
        // 1 günden fazla girilmemiş, streak sıfırlanır
        currentStreak = 0;
        await prefs.setInt(_streakCountKey, 0);
      }
    } else {
      // İlk giriş
      currentStreak = 0;
    }

    if (lastClaimedStr != null) {
      if (lastClaimedStr == todayStr) {
        canClaimToday = false;
      }
    }

    return {
      'streak': currentStreak,
      'canClaimToday': canClaimToday,
      'todayReward': streakRewards[(currentStreak) % streakRewards.length],
    };
  }

  /// Bugünkü streak ödülünü al
  static Future<int> claimStreakReward() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await checkStreakStatus();

    if (status['canClaimToday'] != true) {
      return 0;
    }

    int currentStreak = status['streak'] as int;
    currentStreak += 1;

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final int rewardAmount = streakRewards[(currentStreak - 1) % streakRewards.length];

    await prefs.setInt(_streakCountKey, currentStreak);
    await prefs.setString(_lastLoginDateKey, now.toIso8601String());
    await prefs.setString(_lastClaimedStreakDateKey, todayStr);

    await TokenService.addTokens(rewardAmount);

    return rewardAmount;
  }

  /// Sadece streak sayısını getir
  static Future<int> getStreakCount() async {
    final status = await checkStreakStatus();
    return status['streak'] as int;
  }
}
