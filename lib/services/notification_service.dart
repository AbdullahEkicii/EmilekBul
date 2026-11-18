import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'analytics_service.dart';
import 'streak_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _streakReminderId = 600;
  static const int _leagueReminderId = 700;
  static const String _schemaKey = 'notif_schema_v2';

  /// Günlük hatırlatma kimliği tarihe bağlıdır; böylece o günün bildirimi iptal edilebilir.
  static int _dailyIdFor(DateTime date) =>
      100 + DateTime(date.year, date.month, date.day).difference(DateTime(2024)).inDays % 60;

  /// Hizmeti başlatır
  static Future<void> init() async {
    // Zaman dilimi ayarla
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint("Zaman Dilimi Ayarlandı: $timeZoneName");
    } catch (e) {
      debugPrint("Zaman dilimi algılanamadı, varsayılan kullanılıyor: $e");
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }

    // Bildirim başlatma ayarları
    // iOS izinleri uygulama içi akışta (NotificationPermissionManager) istenir; açılışta sorulmaz.
    const android = AndroidInitializationSettings('ic_stat_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        AnalyticsService.logNotificationOpen(type: response.payload ?? 'unknown');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Kanalları oluştur
    await _createNotificationChannels();
  }

  // Arka planda tıklama işlemi (Gerekirse)
  @pragma('vm:entry-point')
  static void notificationTapBackground(
      NotificationResponse notificationResponse) {
    // Arka plan işlemleri
  }

  static Future<void> _createNotificationChannels() async {
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_channel',
      'notifications.daily_channel_name'.tr(),
      description: 'notifications.daily_channel_desc'.tr(),
      importance: Importance.high,
    );

    final AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
      'social_channel',
      'notifications.social_channel_name'.tr(),
      description: 'notifications.social_channel_desc'.tr(),
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.createNotificationChannel(socialChannel);
    }
  }

  /// Sunucu taraflı FCM push mesajlarını ön planda yerel bildirim olarak gösterir.
  static Future<void> showRemoteMessageNotification({
    required String title,
    required String body,
    String payload = 'fcm',
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000) + 9000;
      await _notifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'social_channel',
            'Social & Events',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_stat_notification',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('showRemoteMessageNotification error: $e');
    }
  }

  /// Tüm bildirimleri iptal et ve önümüzdeki 7 gün için yenilerini planla
  static Future<void> rescheduleNotifications() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final pendingRequests = await getPendingNotifications();
      debugPrint("Mevcut bekleyen bildirim sayısı: ${pendingRequests.length}");

      // Eğer sistemde zaten yeterli bildirim varsa (örneğin 10'dan fazla)
      // ve son planlama üzerinden 48 saat geçmediyse ellemeyelim.
      final prefs = await SharedPreferences.getInstance();
      final lastScheduledStr = prefs.getString('last_notification_schedule');

      bool needsSchedule = false;
      // Eski kimlik şemasındaki (0..26) günlük bildirimleri temizle
      if (!(prefs.getBool(_schemaKey) ?? false)) {
        for (int id = 0; id <= 27; id++) {
          await _notifications.cancel(id);
        }
        await prefs.setBool(_schemaKey, true);
        needsSchedule = true;
      } else if (lastScheduledStr == null) {
        needsSchedule = true;
      } else {
        final lastScheduled = DateTime.parse(lastScheduledStr);
        // 5 günden fazla geçtiyse veya bildirim listesi boşalmaya başladıysa yenile
        if (now.difference(lastScheduled).inHours > 120 ||
            pendingRequests.length < 3) {
          needsSchedule = true;
        }
      }

      if (!needsSchedule) {
        debugPrint(
            "Bildirimler yeterli ve taze görünüyor, yeniden planlama atlandı.");
        _logPendingDetails(pendingRequests);
        return;
      }

      await prefs.setString(
          'last_notification_schedule', now.toIso8601String());

      // Her gün için 1 bildirim planla (14 gün için)
      for (int i = 0; i < 14; i++) {
        await _scheduleDailyNotifications(daysFromNow: i);
      }

      await scheduleWeeklyReminder();
      await scheduleMonthlyAnnouncement();
      await scheduleLeagueEndingReminder();

      debugPrint("Bildirimler güncellendi (14 Günlük + Haftalık + Aylık)");
    } catch (e) {
      debugPrint("Schedule güncelleme hatası: $e");
    }
  }

  /// Dil değişimi gibi durumlarda, eski bildirimleri silip yenilerini zorla planlar
  static Future<void> cancelAndReschedule() async {
    debugPrint("Bildirimler zorla yenileniyor (Dil değişimi vb.)");

    // 1. Tüm mevcut bildirimleri sil
    await cancelAllNotifications();

    // 2. Zaman kontrolü yapmadan (force) yeniden planla
    try {
      final now = tz.TZDateTime.now(tz.local);
      final prefs = await SharedPreferences.getInstance();

      // Son planlama zamanını güncelle
      await prefs.setString(
          'last_notification_schedule', now.toIso8601String());

      // Her gün için 1 bildirim planla (14 gün için)
      for (int i = 0; i < 14; i++) {
        await _scheduleDailyNotifications(daysFromNow: i);
      }

      await scheduleWeeklyReminder();
      await scheduleMonthlyAnnouncement();
      await scheduleLeagueEndingReminder();

      debugPrint("Bildirimler güncellendi (14 Günlük + Haftalık + Aylık)");
    } catch (e) {
      debugPrint("Zorla yenileme hatası: $e");
    }
  }

  static void _logPendingDetails(List<PendingNotificationRequest> requests) {
    for (var r in requests) {
      debugPrint("Bekleyen ID: ${r.id}, Başlık: ${r.title}");
    }
  }

  static Future<void> _scheduleDailyNotifications(
      {required int daysFromNow}) async {
    final now = tz.TZDateTime.now(tz.local);
    final targetDate = now.add(Duration(days: daysFromNow));

    // Günde 1 bildirim (Öğlen 12 ile Akşam 20 arası rastgele)
    final preferred = await _preferredPlayHour();
    final hour = preferred ?? (12 + Random().nextInt(8)); // varsayılan 12..19
    final minute = preferred != null ? Random().nextInt(30) : Random().nextInt(60);

    var notifyTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month,
        targetDate.day, hour, minute);

    if (daysFromNow == 0 && notifyTime.isBefore(now)) {
      // Geçmiş zaman
    } else {
      final isMorning = hour < 15; // İçeriği saate göre ayarla
      final content = _getRandomContent(isMorning: isMorning);
      await _scheduleNotification(
        id: _dailyIdFor(targetDate),
        title: content['title']!,
        body: content['body']!,
        scheduledTime: notifyTime,
        payload: 'daily',
      );
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    String? payload,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        payload: payload,
        NotificationDetails(iOS: const DarwinNotificationDetails(), android: AndroidNotificationDetails(
            'daily_channel',
            'notifications.daily_channel_name'.tr(),
            channelDescription: 'notifications.daily_channel_desc'.tr(),
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF6366F1),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint("Bildirim planlandı: $title @ $scheduledTime");
    } catch (e) {
      debugPrint('Bildirim hatası: $e');
    }
  }

  /// Hemen test bildirimi göster
  static Future<void> showImmediateNotification() async {
    try {
      await _notifications.show(
        777,
        'notifications.test_title'.tr(),
        'notifications.test_body'.tr(),
        NotificationDetails(iOS: const DarwinNotificationDetails(), android: AndroidNotificationDetails(
            'daily_channel',
            'notifications.daily_channel_name'.tr(),
            channelDescription: 'Test kanalı',
            importance: Importance.max,
            priority: Priority.high,
            color: const Color(0xFF6366F1),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Anlık bildirim hatası: $e');
    }
  }

  /// Haftalık hatırlatıcı (Pazartesi 09:00 - Sabit) - Bonuslu Kategoriler Duyurusu
  static Future<void> scheduleWeeklyReminder() async {
    final scheduledTime = _nextInstanceOfWeekly();

    try {
      await _notifications.zonedSchedule(
        999,
        'notifications.weekly_bonus_title'.tr(),
        'notifications.weekly_bonus_body'.tr(),
        scheduledTime,
        NotificationDetails(iOS: const DarwinNotificationDetails(), android: AndroidNotificationDetails(
            'daily_channel',
            'notifications.daily_channel_name'.tr(),
            channelDescription: 'Haftalık 2X bonus kategoriler duyurusu',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFFFF9F43),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Haftalık bildirim hatası: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfWeekly() {
    final now = tz.TZDateTime.now(tz.local);
    int daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMonday == 0 && now.hour >= 9) {
      daysUntilMonday = 7;
    }
    return tz.TZDateTime(
        tz.local, now.year, now.month, now.day + daysUntilMonday, 9);
  }

  /// Aylık duyuru (Her ayın 1'i saat 10:00)
  static Future<void> scheduleMonthlyAnnouncement() async {
    final scheduledTime = _nextInstanceOfMonthly();
    try {
      await _notifications.zonedSchedule(
        888,
        'notifications.monthly_title'.tr(),
        'notifications.monthly_body'.tr(),
        scheduledTime,
        NotificationDetails(iOS: const DarwinNotificationDetails(), android: AndroidNotificationDetails(
            'monthly_channel',
            'notifications.monthly_channel_name'.tr(),
            channelDescription: 'notifications.monthly_channel_desc'.tr(),
            importance: Importance.max,
            priority: Priority.max,
            color: const Color(0xFFFFD700),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
      debugPrint("Aylık bildirim planlandı: $scheduledTime");
    } catch (e) {
      debugPrint('Aylık bildirim hatası: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfMonthly() {
    final now = tz.TZDateTime.now(tz.local);
    if (now.day == 1 && now.hour < 10) {
      return tz.TZDateTime(tz.local, now.year, now.month, 1, 10);
    } else {
      var nextMonth = now.month + 1;
      var year = now.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        year++;
      }
      return tz.TZDateTime(tz.local, year, nextMonth, 1, 10);
    }
  }

  // ---- Saatlik oyun alışkanlığı (24 elemanlı sayaç) ----
  static const String _hourHistKey = 'play_hour_histogram';
  static const int _minSamplesForPreference = 5;

  /// Test bitişinde çağrılır; o saatin sayacını artırır.
  static Future<void> recordPlayHour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hist = _readHistogram(prefs);
      hist[DateTime.now().hour]++;
      await prefs.setStringList(_hourHistKey, hist.map((e) => e.toString()).toList());
    } catch (e) {
      debugPrint('recordPlayHour error: $e');
    }
  }

  static List<int> _readHistogram(SharedPreferences prefs) {
    final raw = prefs.getStringList(_hourHistKey);
    if (raw == null || raw.length != 24) return List<int>.filled(24, 0);
    return raw.map((e) => int.tryParse(e) ?? 0).toList();
  }

  /// En çok oynanan saat (yeterli veri yoksa null). Gece saatleri 9..21 aralığına çekilir.
  static Future<int?> _preferredPlayHour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hist = _readHistogram(prefs);
      final total = hist.fold<int>(0, (a, b) => a + b);
      if (total < _minSamplesForPreference) return null;
      var best = 0;
      for (int h = 1; h < 24; h++) {
        if (hist[h] > hist[best]) best = h;
      }
      return best.clamp(9, 21);
    } catch (_) {
      return null;
    }
  }

  /// [base] gününe tercih edilen saati uygular (veri yoksa base'i aynen döner).
  static Future<tz.TZDateTime> _atPreferredHour(tz.TZDateTime base) async {
    final h = await _preferredPlayHour();
    if (h == null) return base;
    return tz.TZDateTime(tz.local, base.year, base.month, base.day, h, Random().nextInt(30));
  }

  // Kimlikler: 500 (2s), 501 (24s), 502 (3g), 503 (7g), 504 (14g), 505 (ilk günler teaser)
  static const int _teaserId = 505;
  static const String _teaserDateKey = 'retention_teaser_date';

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Quiz tamamlandıktan sonra re-engagement bildirimleri planla
  static Future<void> scheduleReEngagementNotifications() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final prefs = await SharedPreferences.getInstance();

      // İlk kez quiz tamamlayan kullanıcı mı kontrol et
      final isFirstQuiz = !prefs.containsKey('first_quiz_completed');
      if (isFirstQuiz) {
        await prefs.setBool('first_quiz_completed', true);
        await prefs.setString('first_quiz_date', _ymd(now));
      }

      // 1. 2 saat sonra (sadece ilk testten sonra; aktif oyuncuyu gün içinde rahatsız etmemek için)
      if (isFirstQuiz) {
        await _scheduleNotification(
          id: 500,
          title: 'notifications.reengage_2h_title'.tr(),
          body: 'notifications.reengage_2h_body'.tr(),
          scheduledTime: now.add(const Duration(hours: 2)),
          payload: 'reengage_2h',
        );
      }

      // 2. 24 saat sonra (ödül metni gerçek seri ödülüne bağlıdır)
      final reward = await StreakService.getNextDayRewardEstimate();
      await _scheduleNotification(
        id: 501,
        title: 'notifications.reengage_24h_title'.tr(),
        body: 'retention.day1_body'.tr(args: [reward.toString()]),
        payload: 'reengage_24h',
        scheduledTime: now.add(const Duration(hours: 24)),
      );

      // 3. İlk 3 gün: ertesi gün tercih edilen saatte "yarın dönersen" bildirimi
      await _scheduleFirstDaysTeaser(now, prefs, reward);

      // 4. Win-back: 3 / 7 / 14 gün
      await _scheduleWinBack(now);

      debugPrint("Re-engagement bildirimleri planlandı (2h, 24h, teaser, 3d, 7d, 14d)");
    } catch (e) {
      debugPrint("Re-engagement bildirim hatası: $e");
    }
  }

  /// İlk 3 günde (ilk testin günü + sonraki 2 gün) yarın için ödül hatırlatması.
  static Future<void> _scheduleFirstDaysTeaser(
      tz.TZDateTime now, SharedPreferences prefs, int reward) async {
    final firstStr = prefs.getString('first_quiz_date');
    if (firstStr == null) return;
    final first = DateTime.tryParse(firstStr);
    if (first == null) return;
    final today = DateTime(now.year, now.month, now.day);
    final dayIndex = today.difference(DateTime(first.year, first.month, first.day)).inDays;
    if (dayIndex < 0 || dayIndex > 2) return;

    final tomorrow = today.add(const Duration(days: 1));
    final base = await _atPreferredHour(
        tz.TZDateTime(tz.local, tomorrow.year, tomorrow.month, tomorrow.day, 10));
    await _scheduleNotification(
      id: _teaserId,
      title: 'retention.teaser_title'.tr(),
      body: 'retention.teaser_body'.tr(args: [reward.toString()]),
      scheduledTime: base,
      payload: 'first_days_teaser',
    );
    await prefs.setString(_teaserDateKey, _ymd(tomorrow));
  }

  /// 3/7/14 gün giriş yapmayanlar için farklı, genel (veriye dayanmayan) içerikler.
  static Future<void> _scheduleWinBack(tz.TZDateTime now) async {
    const steps = [
      (id: 502, days: 3, key: '3d'),
      (id: 503, days: 7, key: '7d'),
      (id: 504, days: 14, key: '14d'),
    ];
    for (final step in steps) {
      final t = await _atPreferredHour(now.add(Duration(days: step.days)));
      await _scheduleNotification(
        id: step.id,
        title: 'retention.winback_${step.key}_title'.tr(),
        body: 'retention.winback_${step.key}_body'.tr(),
        payload: 'reengage_${step.key}',
        scheduledTime: t,
      );
    }
  }

  /// Uygulama açıldığında: eski win-back bildirimlerini iptal edip yeniden planlar.
  /// (500/501 ilk gün akışına aittir; dokunulmaz. Teaser, günü geldiyse iptal edilir.)
  static Future<void> refreshWinBackNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('first_quiz_completed')) return;
      for (int id = 502; id <= 504; id++) {
        await _notifications.cancel(id);
      }
      final teaserDate = prefs.getString(_teaserDateKey);
      if (teaserDate != null && _ymd(DateTime.now()).compareTo(teaserDate) >= 0) {
        await _notifications.cancel(_teaserId);
      }
      await _scheduleWinBack(tz.TZDateTime.now(tz.local));
    } catch (e) {
      debugPrint('refreshWinBackNotifications error: $e');
    }
  }

  /// Re-engagement bildirimlerini iptal et (kullanıcı geri döndüğünde)
  static Future<void> cancelReEngagementNotifications() async {
    for (int id = 500; id <= 505; id++) {
      await _notifications.cancel(id);
    }
    debugPrint("Re-engagement bildirimleri iptal edildi");
  }

  /// Kullanıcı bugün test çözdü: bugünkü genel hatırlatmayı gönderme.
  static Future<void> markPlayedToday() async {
    try {
      await _notifications.cancel(_dailyIdFor(DateTime.now()));
      await recordPlayHour();
    } catch (e) {
      debugPrint('markPlayedToday error: $e');
    }
  }

  /// "Serin bozulmak üzere" hatırlatması: bugün ödül alınmadıysa bugün 20:00'de,
  /// alındıysa yarın 20:00'de (yarın girmezse) gösterilir.
  static Future<void> scheduleStreakReminder({required int streak, required bool claimedToday}) async {
    try {
      await _notifications.cancel(_streakReminderId);
      if (streak <= 0) return;
      final now = tz.TZDateTime.now(tz.local);
      var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
      if (claimedToday) target = target.add(const Duration(days: 1));
      if (target.isBefore(now)) return;
      await _scheduleNotification(
        id: _streakReminderId,
        title: 'notifications.streak_risk_title'.tr(),
        body: 'notifications.streak_risk_body'.tr(args: [streak.toString()]),
        scheduledTime: target,
        payload: 'streak_risk',
      );
    } catch (e) {
      debugPrint('scheduleStreakReminder error: $e');
    }
  }

  /// Haftalık lig kapanış hatırlatması: her Pazar 18:00.
  static Future<void> scheduleLeagueEndingReminder() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18)
          .add(Duration(days: (DateTime.sunday - now.weekday) % 7));
      if (target.isBefore(now)) target = target.add(const Duration(days: 7));
      await _notifications.zonedSchedule(
        _leagueReminderId,
        'notifications.league_ending_title'.tr(),
        'notifications.league_ending_body'.tr(),
        target,
        NotificationDetails(iOS: const DarwinNotificationDetails(), android: AndroidNotificationDetails(
            'daily_channel',
            'notifications.daily_channel_name'.tr(),
            channelDescription: 'notifications.daily_channel_desc'.tr(),
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF6366F1),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'league_ending',
      );
    } catch (e) {
      debugPrint('scheduleLeagueEndingReminder error: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Map<String, String> _getRandomContent({required bool isMorning}) {
    final prefix = isMorning ? 'morning' : 'evening';
    final random = Random();

    // Her kategori için 15 farklı mesajımız var (0-14 arası index)
    int index = random.nextInt(15);

    return {
      'title': 'notifications.${prefix}_title_$index'.tr(),
      'body': 'notifications.${prefix}_body_$index'.tr()
    };
  }

  static Future<bool?> areNotificationsEnabled() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.areNotificationsEnabled();
  }

  static Future<bool?> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestNotificationsPermission();
  }

  /// Anlık Bildirim Göster (Arkadaş isteği, düello daveti, dürtme vb.)
  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'social_channel',
        'notifications.social_channel_name'.tr(),
        channelDescription: 'notifications.social_channel_desc'.tr(),
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: 'ic_stat_notification',
      );

      final notificationDetails = NotificationDetails(iOS: const DarwinNotificationDetails(), android: androidDetails);

      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }
}
