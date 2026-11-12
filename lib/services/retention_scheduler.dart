import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Sandık ve günlük hedef hatırlatmalarını planlayan, **izole-güvenli** katman.
/// Hem uygulama izolatında hem WorkManager arka plan izolatında çalışır; bu yüzden yalnızca
/// SharedPreferences + yerel bildirim + zaman dilimi kullanır (Firebase/Firestore YOK).
///
/// Güvenli tasarım kuralları:
/// - Sürekli çalışan servis yok; zamanlayıcılar zaman damgasıdır, bildirimler OS alarmıyla planlanır.
/// - Sessiz saatler (22:00–08:00) içine bildirim düşmez, ertesi sabaha ertelenir.
/// - Kullanıcı ayarlardan kapatabilir; kapalıysa hiçbir şey planlanmaz ve mevcutlar iptal edilir.
/// - 7 gündür girmeyen kullanıcıya bu hatırlatmalar gönderilmez (win-back ayrıdır, sınırlıdır).
class RetentionScheduler {
  static const int chestId = 801;
  static const int goalId = 802;

  static const String kReminders = 'reminders_enabled';
  static const String kChestNext = 'ret_chest_next_ms';
  static const String kGoalDate = 'ret_goal_date';
  static const String kGoalProgress = 'ret_goal_progress';
  static const String kGoalTarget = 'ret_goal_target';
  static const String kGoalClaimed = 'ret_goal_claimed';
  static const String kLastActive = 'ret_last_active_ms';

  // Bildirim metinleri uygulama açıkken (easy_localization ile) önbelleğe alınır;
  // arka plan izolatında çeviri motoru olmadığı için buradan okunur.
  static const String kTxtChestTitle = 'ret_txt_chest_title';
  static const String kTxtChestBody = 'ret_txt_chest_body';
  static const String kTxtGoalTitle = 'ret_txt_goal_title';
  static const String kTxtGoalBody = 'ret_txt_goal_body';

  static const int quietStartHour = 22;
  static const int quietEndHour = 8;
  static const int lapsedDays = 7;

  static bool _tzReady = false;

  static String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<bool> remindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kReminders) ?? true;
  }

  /// Geri dönüş paketi: bu süre uzak kalıp dönen kullanıcıya çift jeton penceresi açılır.
  static const String kComebackUntil = 'comeback_double_until_ms';
  static const Duration comebackAwayThreshold = Duration(days: 3);
  static const Duration comebackWindow = Duration(hours: 24);

  static Future<void> markActive() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastActive = prefs.getInt(kLastActive) ?? 0;
    if (lastActive > 0 && now - lastActive >= comebackAwayThreshold.inMilliseconds) {
      await prefs.setInt(kComebackUntil, now + comebackWindow.inMilliseconds);
    }
    await prefs.setInt(kLastActive, now);
  }

  static Future<void> ensureTz() async {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Varsayılan konum kalır
    }
    _tzReady = true;
  }

  static tz.TZDateTime _respectQuietHours(tz.TZDateTime t) {
    if (t.hour >= quietStartHour) {
      final n = t.add(const Duration(days: 1));
      return tz.TZDateTime(tz.local, n.year, n.month, n.day, quietEndHour, 30);
    }
    if (t.hour < quietEndHour) {
      return tz.TZDateTime(tz.local, t.year, t.month, t.day, quietEndHour, 30);
    }
    return t;
  }

  /// Planlanmış sandık/hedef bildirimlerini mevcut duruma göre yeniden kurar.
  /// [fromWorker] true ise (arka plan izolatı) bildirim eklentisi bu izolatta başlatılır.
  static Future<void> refresh({bool fromWorker = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fromWorker) await prefs.reload(); // UI izolatının yazdığı güncel değerleri oku
      await ensureTz();

      final plugin = FlutterLocalNotificationsPlugin();
      if (fromWorker) {
        // Yalnızca arka plan izolatında: UI izolatındaki tıklama geri çağrılarını ezmemek için
        await plugin.initialize(const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ));
      }

      final enabled = prefs.getBool(kReminders) ?? true;
      final lastActive = prefs.getInt(kLastActive) ?? 0;
      final lapsed = lastActive == 0 ||
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastActive)).inDays >=
              lapsedDays;

      if (!enabled || lapsed) {
        await plugin.cancel(chestId);
        await plugin.cancel(goalId);
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      final chestAt = await _refreshChest(plugin, prefs, now);
      // Günde en fazla 1 hatırlatma: sandık bildirimi bugüne planlıysa hedef notu atlanır
      final chestToday = chestAt != null && ymd(chestAt) == ymd(now);
      await _refreshGoal(plugin, prefs, now, skip: chestToday);
    } catch (e) {
      debugPrint('RetentionScheduler.refresh error: $e');
    }
  }

  static Future<tz.TZDateTime?> _refreshChest(
      FlutterLocalNotificationsPlugin plugin, SharedPreferences prefs, tz.TZDateTime now) async {
    final nextMs = prefs.getInt(kChestNext);
    final title = prefs.getString(kTxtChestTitle);
    final body = prefs.getString(kTxtChestBody);
    if (nextMs == null || title == null || body == null) {
      await plugin.cancel(chestId);
      return null;
    }
    final next = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, nextMs);
    if (!next.isAfter(now)) {
      // Sandık zaten hazır: eski planı temizle, kullanıcıyı boşuna bildirme
      await plugin.cancel(chestId);
      return null;
    }
    final when = _respectQuietHours(next);
    await _schedule(plugin, chestId, title, body, when, 'chest_ready');
    return when;
  }

  static Future<void> _refreshGoal(
      FlutterLocalNotificationsPlugin plugin, SharedPreferences prefs, tz.TZDateTime now,
      {bool skip = false}) async {
    final today = ymd(now);
    final progress = prefs.getString(kGoalDate) == today ? (prefs.getInt(kGoalProgress) ?? 0) : 0;
    final target = prefs.getInt(kGoalTarget) ?? 3;
    final claimed = prefs.getBool(kGoalClaimed) ?? false;
    final title = prefs.getString(kTxtGoalTitle);
    final body = prefs.getString(kTxtGoalBody);
    final at = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 30);

    // Yalnızca bugün başlamış ama bitmemiş hedef için, akşam bir kez
    if (skip ||
        title == null ||
        body == null ||
        claimed ||
        progress <= 0 ||
        progress >= target ||
        !at.isAfter(now)) {
      await plugin.cancel(goalId);
      return;
    }
    final remaining = (target - progress).clamp(1, target);
    await _schedule(plugin, goalId, title, body.replaceAll('{}', '$remaining'), at, 'goal_nudge');
  }

  static Future<void> _schedule(FlutterLocalNotificationsPlugin plugin, int id, String title,
      String body, tz.TZDateTime when, String payload) async {
    await plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(iOS: DarwinNotificationDetails(), android: AndroidNotificationDetails(
          'daily_channel',
          'Daily reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: Color(0xFF6366F1),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> cancelAll() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(chestId);
      await plugin.cancel(goalId);
      await plugin.cancel(810); // kişisel öneri bildirimi (NudgeEngine.nudgeId)
    } catch (_) {}
  }
}
