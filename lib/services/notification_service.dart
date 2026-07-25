import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Hizmeti başlatır
  static Future<void> init() async {
    // Zaman dilimi ayarla
    tzData.initializeTimeZones();
    try {
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print("Zaman Dilimi Ayarlandı: $timeZoneName");
    } catch (e) {
      print("Zaman dilimi algılanamadı, varsayılan kullanılıyor: $e");
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }

    // Bildirim başlatma ayarları
    const android = AndroidInitializationSettings('ic_stat_notification');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Bildirime tıklanınca yapılacak işlemler
        print('Bildirim tıklandı: ${response.payload}');
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

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Tüm bildirimleri iptal et ve önümüzdeki 7 gün için yenilerini planla
  static Future<void> rescheduleNotifications() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final pendingRequests = await getPendingNotifications();
      print("Mevcut bekleyen bildirim sayısı: ${pendingRequests.length}");

      // Eğer sistemde zaten yeterli bildirim varsa (örneğin 10'dan fazla)
      // ve son planlama üzerinden 48 saat geçmediyse ellemeyelim.
      final prefs = await SharedPreferences.getInstance();
      final lastScheduledStr = prefs.getString('last_notification_schedule');

      bool needsSchedule = false;
      if (lastScheduledStr == null) {
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
        print(
            "Bildirimler yeterli ve taze görünüyor, yeniden planlama atlandı.");
        _logPendingDetails(pendingRequests);
        return;
      }

      await prefs.setString(
          'last_notification_schedule', now.toIso8601String());

      // Her gün için 2 farklı bildirim planla (5 gün için)
      for (int i = 0; i < 5; i++) {
        await _scheduleDailyNotifications(daysFromNow: i);
      }

      await scheduleWeeklyReminder();
      await scheduleMonthlyAnnouncement();

      print("Bildirimler güncellendi (7 Günlük + Haftalık + Aylık)");
    } catch (e) {
      print("Schedule güncelleme hatası: $e");
    }
  }

  /// Dil değişimi gibi durumlarda, eski bildirimleri silip yenilerini zorla planlar
  static Future<void> cancelAndReschedule() async {
    print("Bildirimler zorla yenileniyor (Dil değişimi vb.)");

    // 1. Tüm mevcut bildirimleri sil
    await cancelAllNotifications();

    // 2. Zaman kontrolü yapmadan (force) yeniden planla
    try {
      final now = tz.TZDateTime.now(tz.local);
      final prefs = await SharedPreferences.getInstance();

      // Son planlama zamanını güncelle
      await prefs.setString(
          'last_notification_schedule', now.toIso8601String());

      // Her gün için 2 farklı bildirim planla (5 gün için)
      for (int i = 0; i < 5; i++) {
        await _scheduleDailyNotifications(daysFromNow: i);
      }

      await scheduleWeeklyReminder();
      await scheduleMonthlyAnnouncement();

      print("Bildirimler güncellendi (5 Günlük + Haftalık + Aylık)");
    } catch (e) {
      print("Zorla yenileme hatası: $e");
    }
  }

  static void _logPendingDetails(List<PendingNotificationRequest> requests) {
    for (var r in requests) {
      print("Bekleyen ID: ${r.id}, Başlık: ${r.title}");
    }
  }

  static Future<void> _scheduleDailyNotifications(
      {required int daysFromNow}) async {
    final now = tz.TZDateTime.now(tz.local);
    final targetDate = now.add(Duration(days: daysFromNow));

    // 1. Bildirim: Sabah / Öğle (12:00 - 15:00 arası rastgele)
    final morningHour = 12 + Random().nextInt(4); // 12,13,14,15
    final morningMinute = Random().nextInt(60);

    var morningTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month,
        targetDate.day, morningHour, morningMinute);

    if (daysFromNow == 0 && morningTime.isBefore(now)) {
      // Geçmiş
    } else {
      final content = _getRandomContent(isMorning: true);
      await _scheduleNotification(
        id: daysFromNow * 2,
        title: content['title']!,
        body: content['body']!,
        scheduledTime: morningTime,
      );
    }

    // 2. Bildirim: Akşam (20:00 - 24:00 arası rastgele)
    final eveningHour = 20 + Random().nextInt(4); // 20,21,22,23
    final eveningMinute = Random().nextInt(60);

    var eveningTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month,
        targetDate.day, eveningHour, eveningMinute);

    if (daysFromNow == 0 && eveningTime.isBefore(now)) {
      // Geçmiş
    } else {
      final content = _getRandomContent(isMorning: false);
      await _scheduleNotification(
        id: (daysFromNow * 2) + 1,
        title: content['title']!,
        body: content['body']!,
        scheduledTime: eveningTime,
      );
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
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
      print("Bildirim planlandı: $title @ $scheduledTime");
    } catch (e) {
      print('Bildirim hatası: $e');
    }
  }

  /// Hemen test bildirimi göster
  static Future<void> showImmediateNotification() async {
    try {
      await _notifications.show(
        777,
        'notifications.test_title'.tr(),
        'notifications.test_body'.tr(),
        NotificationDetails(
          android: AndroidNotificationDetails(
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
      print('Anlık bildirim hatası: $e');
    }
  }

  /// Haftalık hatırlatıcı (Pazartesi 09:00 - Sabit)
  static Future<void> scheduleWeeklyReminder() async {
    final scheduledTime = _nextInstanceOfWeekly();

    try {
      await _notifications.zonedSchedule(
        999,
        'notifications.weekly_title'.tr(),
        'notifications.weekly_body'.tr(),
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_channel',
            'notifications.daily_channel_name'.tr(),
            channelDescription: 'Haftalık hatırlatıcı',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF6366F1),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      print('Haftalık bildirim hatası: $e');
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
        NotificationDetails(
          android: AndroidNotificationDetails(
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
      print("Aylık bildirim planlandı: $scheduledTime");
    } catch (e) {
      print('Aylık bildirim hatası: $e');
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

  /// Quiz tamamlandıktan sonra re-engagement bildirimleri planla
  static Future<void> scheduleReEngagementNotifications() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final prefs = await SharedPreferences.getInstance();

      // İlk kez quiz tamamlayan kullanıcı mı kontrol et
      final isFirstQuiz = !prefs.containsKey('first_quiz_completed');
      if (isFirstQuiz) {
        await prefs.setBool('first_quiz_completed', true);
      }

      // Re-engagement bildirimleri (benzersiz ID'ler: 500-503)
      // 1. 2 saat sonra
      final twoHoursLater = now.add(const Duration(hours: 2));
      await _scheduleNotification(
        id: 500,
        title: 'notifications.reengage_2h_title'.tr(),
        body: 'notifications.reengage_2h_body'.tr(),
        scheduledTime: twoHoursLater,
      );

      // 2. 24 saat sonra
      final oneDayLater = now.add(const Duration(hours: 24));
      await _scheduleNotification(
        id: 501,
        title: 'notifications.reengage_24h_title'.tr(),
        body: 'notifications.reengage_24h_body'.tr(),
        scheduledTime: oneDayLater,
      );

      // 3. 3 gün sonra
      final threeDaysLater = now.add(const Duration(days: 3));
      await _scheduleNotification(
        id: 502,
        title: 'notifications.reengage_3d_title'.tr(),
        body: 'notifications.reengage_3d_body'.tr(),
        scheduledTime: threeDaysLater,
      );

      // 4. 7 gün sonra
      final sevenDaysLater = now.add(const Duration(days: 7));
      await _scheduleNotification(
        id: 503,
        title: 'notifications.reengage_7d_title'.tr(),
        body: 'notifications.reengage_7d_body'.tr(),
        scheduledTime: sevenDaysLater,
      );

      print("Re-engagement bildirimleri planlandı (2h, 24h, 3d, 7d)");
    } catch (e) {
      print("Re-engagement bildirim hatası: $e");
    }
  }

  /// Re-engagement bildirimlerini iptal et (kullanıcı geri döndüğünde)
  static Future<void> cancelReEngagementNotifications() async {
    for (int id = 500; id <= 503; id++) {
      await _notifications.cancel(id);
    }
    print("Re-engagement bildirimleri iptal edildi");
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
}
