import 'nudge_engine.dart';
import 'dart:convert';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'background_worker.dart';
import 'cloud_state_service.dart';
import 'home_widget_service.dart';
import 'remote_flags.dart';
import 'retention_scheduler.dart';
import 'streak_service.dart';
import 'token_service.dart';

class GoalState {
  final int progress;
  final int target;
  final bool claimed;
  const GoalState(this.progress, this.target, this.claimed);
  bool get reached => progress >= target;
  bool get claimable => reached && !claimed;
}

class ChestState {
  final bool ready;
  final Duration remaining;
  const ChestState(this.ready, this.remaining);
}

/// Günlük hedef + zamanlı sandık döngüsü (oyuncuyu gün içinde geri getiren iki ritim):
/// 1) Günlük hedef: gün içinde N test bitir → hedef sandığı açılır.
/// 2) Ücretsiz sandık: her X saatte bir açılabilir (zaman damgası; uygulama kapalıyken de "işler").
/// Bu iki durum bulutla da eşlenir (yeniden kurulumla sıfırlanmasın diye).
class RetentionEngine {
  static final Random _rnd = Random();

  static int _between(int min, int max) =>
      max <= min ? min : min + _rnd.nextInt(max - min + 1);

  // ---------------------------------------------------------------- günlük hedef
  static Future<GoalState> getGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final today = RetentionScheduler.ymd(DateTime.now());
    // Onboarding'de oyuncunun seçtiği hedef, uzaktan ayarlanan varsayılanın önüne geçer
    final target = prefs.getInt('user_daily_goal') ?? RemoteFlags.dailyGoalTarget;
    if (prefs.getString(RetentionScheduler.kGoalDate) != today) {
      await prefs.setString(RetentionScheduler.kGoalDate, today);
      await prefs.setInt(RetentionScheduler.kGoalProgress, 0);
      await prefs.setBool(RetentionScheduler.kGoalClaimed, false);
    }
    await prefs.setInt(RetentionScheduler.kGoalTarget, target);
    return GoalState(
      prefs.getInt(RetentionScheduler.kGoalProgress) ?? 0,
      target,
      prefs.getBool(RetentionScheduler.kGoalClaimed) ?? false,
    );
  }

  /// Bir test/düello/günlük meydan okuma bittiğinde çağrılır.
  static const String _weekKey = 'weekly_chest_v1';
  static const int weeklyTargetDays = 4;
  static const int weeklyChestTokens = 100;

  static String _weekStart(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    return RetentionScheduler.ymd(monday);
  }

  /// Bu hafta kaç farklı günde test bitirildiği ve sandığın alınıp alınmadığı.
  static Future<(int, bool)> getWeekly() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_weekKey);
    if (raw == null) return (0, false);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    if (m['week'] != _weekStart(DateTime.now())) return (0, false);
    return ((m['days'] as List).length, m['claimed'] == true);
  }

  static Future<void> _recordPlayDay() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final week = _weekStart(now);
    final today = RetentionScheduler.ymd(now);
    final raw = prefs.getString(_weekKey);
    Map<String, dynamic> m = raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
    if (m['week'] != week) m = {'week': week, 'days': <String>[], 'claimed': false};
    final days = List<String>.from(m['days'] as List? ?? const []);
    if (!days.contains(today)) days.add(today);
    m['days'] = days;
    await prefs.setString(_weekKey, jsonEncode(m));
  }

  /// Haftalık sandığı açar; kazanılan jeton (açılamazsa 0).
  static Future<int> claimWeeklyChest() async {
    final (days, claimed) = await getWeekly();
    if (claimed || days < weeklyTargetDays) return 0;
    final prefs = await SharedPreferences.getInstance();
    final m = jsonDecode(prefs.getString(_weekKey)!) as Map<String, dynamic>;
    m['claimed'] = true; // önce işaretle (çift ödül önlemi)
    await prefs.setString(_weekKey, jsonEncode(m));
    await TokenService.addTokens(weeklyChestTokens, source: 'weekly_chest');
    // Haftalık hedef tamamlanınca bir seri dondurma da hediye (üst sınırda sessizce atlanır)
    await StreakService.grantFreeze();
    AnalyticsService.logCustomEvent(name: 'weekly_chest_claimed', parameters: {'tokens': weeklyChestTokens});
    await _saveToCloud();
    return weeklyChestTokens;
  }

  static Future<void> onActivityCompleted() async {
    try {
      await _recordPlayDay();
      final prefs = await SharedPreferences.getInstance();
      final goal = await getGoal();
      final progress = goal.progress + 1;
      await prefs.setInt(RetentionScheduler.kGoalProgress, progress);
      await RetentionScheduler.markActive();
      if (progress == goal.target) {
        AnalyticsService.logCustomEvent(name: 'daily_goal_reached', parameters: {'target': goal.target});
      }
      await _saveToCloud();
      await RetentionScheduler.refresh();
    } catch (e) {
      debugPrint('RetentionEngine.onActivityCompleted error: $e');
    }
  }

  /// Hedef sandığını açar; kazanılan jeton sayısını döner (açılamazsa 0).
  static Future<int> claimGoalChest() async {
    final goal = await getGoal();
    if (!goal.claimable) return 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(RetentionScheduler.kGoalClaimed, true); // önce işaretle (çift ödül önlemi)
    final reward = _between(RemoteFlags.goalChestMinTokens, RemoteFlags.goalChestMaxTokens);
    await TokenService.addTokens(reward, source: 'goal_chest');
    AnalyticsService.logCustomEvent(name: 'goal_chest_claimed', parameters: {'tokens': reward});
    await _saveToCloud();
    await RetentionScheduler.refresh();
    return reward;
  }

  // ---------------------------------------------------------------- zamanlı sandık
  static Future<ChestState> getChest() async {
    final prefs = await SharedPreferences.getInstance();
    final nextMs = prefs.getInt(RetentionScheduler.kChestNext);
    if (nextMs == null) return const ChestState(true, Duration.zero); // ilk sandık hemen hazır
    final remaining = DateTime.fromMillisecondsSinceEpoch(nextMs).difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      return const ChestState(true, Duration.zero);
    }
    return ChestState(false, remaining);
  }

  /// Zamanlı sandığı açar; kazanılan jeton sayısını döner (henüz hazır değilse 0).
  static Future<int> claimTimerChest() async {
    final chest = await getChest();
    if (!chest.ready) return 0;
    final prefs = await SharedPreferences.getInstance();
    final next = DateTime.now().add(Duration(hours: RemoteFlags.chestIntervalHours));
    await prefs.setInt(RetentionScheduler.kChestNext, next.millisecondsSinceEpoch);
    final reward = _between(RemoteFlags.chestMinTokens, RemoteFlags.chestMaxTokens);
    await TokenService.addTokens(reward, source: 'timer_chest');
    AnalyticsService.logCustomEvent(name: 'timer_chest_claimed', parameters: {'tokens': reward});
    await RetentionScheduler.markActive();
    await _saveToCloud();
    await RetentionScheduler.refresh();
    return reward;
  }

  // ---------------------------------------------------------------- yaşam döngüsü
  /// Uygulama açıldığında/öne geldiğinde: bildirim metinlerini önbelleğe al, aktifliği işaretle,
  /// bildirimleri güncel duruma göre kur ve arka plan görevini ayarla.
  static Future<void> onAppOpen() async {
    try {
      await cacheNotificationTexts();
      await HomeWidgetService.refresh();
      await RetentionScheduler.markActive();
      await BackgroundWorker.sync();
      await RetentionScheduler.refresh();
      await NudgeEngine.cacheTexts();
      await NudgeEngine.evaluate();
    } catch (e) {
      debugPrint('RetentionEngine.onAppOpen error: $e');
    }
  }

  /// Arka plan izolatında çeviri motoru olmadığından, güncel dildeki metinler burada saklanır.
  static Future<void> cacheNotificationTexts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RetentionScheduler.kTxtChestTitle, 'retention_hub.notif_chest_title'.tr());
    await prefs.setString(RetentionScheduler.kTxtChestBody, 'retention_hub.notif_chest_body'.tr());
    await prefs.setString(RetentionScheduler.kTxtGoalTitle, 'retention_hub.notif_goal_title'.tr());
    await prefs.setString(RetentionScheduler.kTxtGoalBody, 'retention_hub.notif_goal_body'.tr());
  }

  static Future<bool> remindersEnabled() => RetentionScheduler.remindersEnabled();

  static Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(RetentionScheduler.kReminders, enabled);
    AnalyticsService.logCustomEvent(name: 'reminders_toggled', parameters: {'enabled': enabled ? 1 : 0});
    if (enabled) {
      await onAppOpen();
    } else {
      await RetentionScheduler.cancelAll();
      await BackgroundWorker.sync();
    }
  }

  // ---------------------------------------------------------------- bulut eşlemesi
  static Future<void> _saveToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    await CloudStateService.save('retention', {
      'goalDate': prefs.getString(RetentionScheduler.kGoalDate),
      'goalProgress': prefs.getInt(RetentionScheduler.kGoalProgress) ?? 0,
      'goalClaimed': prefs.getBool(RetentionScheduler.kGoalClaimed) ?? false,
      'chestNextMs': prefs.getInt(RetentionScheduler.kChestNext),
    });
  }

  /// Aynı gün için bulut verisi yerelden ilerideyse onu uygular (yeniden kurulum istismarını önler).
  static Future<void> importState(Map<String, dynamic> cloud) async {
    if (cloud.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = RetentionScheduler.ymd(DateTime.now());
      if (cloud['goalDate'] == today) {
        final localToday = prefs.getString(RetentionScheduler.kGoalDate) == today;
        final localProgress = localToday ? (prefs.getInt(RetentionScheduler.kGoalProgress) ?? 0) : 0;
        final cloudProgress = (cloud['goalProgress'] as num?)?.toInt() ?? 0;
        await prefs.setString(RetentionScheduler.kGoalDate, today);
        await prefs.setInt(RetentionScheduler.kGoalProgress, max(localProgress, cloudProgress));
        final localClaimed = localToday && (prefs.getBool(RetentionScheduler.kGoalClaimed) ?? false);
        await prefs.setBool(
            RetentionScheduler.kGoalClaimed, localClaimed || cloud['goalClaimed'] == true);
      }
      final cloudNext = (cloud['chestNextMs'] as num?)?.toInt();
      final localNext = prefs.getInt(RetentionScheduler.kChestNext);
      if (cloudNext != null && (localNext == null || cloudNext > localNext)) {
        await prefs.setInt(RetentionScheduler.kChestNext, cloudNext);
      }
    } catch (e) {
      debugPrint('RetentionEngine.importState error: $e');
    }
  }
}
