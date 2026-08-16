import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
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
    const android = AndroidInitializationSettings('ic_stat_notification');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Bildirime tıklanınca yapılacak işlemler
        debugPrint('Bildirim tıklandı: ${response.payload}');
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

    final AndroidNotificationChannel socialChannel = const AndroidNotificationChannel(
      'social_channel',
      'Arkadaş & Düello Bildirimleri',
      description: 'Arkadaşlık istekleri, düello davetleri ve dürtme bildirimleri',
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
    final hour = 12 + Random().nextInt(8); // 12,13..19
    final minute = Random().nextInt(60);

    var notifyTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month,
        targetDate.day, hour, minute);

    if (daysFromNow == 0 && notifyTime.isBefore(now)) {
      // Geçmiş zaman
    } else {
      final isMorning = hour < 15; // İçeriği saate göre ayarla
      final content = _getRandomContent(isMorning: isMorning);
      await _scheduleNotification(
        id: daysFromNow * 2, // Çakışmamak için
        title: content['title']!,
        body: content['body']!,
        scheduledTime: notifyTime,
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
        NotificationDetails(
          android: AndroidNotificationDetails(
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

      debugPrint("Re-engagement bildirimleri planlandı (2h, 24h, 3d, 7d)");
    } catch (e) {
      debugPrint("Re-engagement bildirim hatası: $e");
    }
  }

  /// Re-engagement bildirimlerini iptal et (kullanıcı geri döndüğünde)
  static Future<void> cancelReEngagementNotifications() async {
    for (int id = 500; id <= 503; id++) {
      await _notifications.cancel(id);
    }
    debugPrint("Re-engagement bildirimleri iptal edildi");
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
      const androidDetails = AndroidNotificationDetails(
        'social_channel',
        'Arkadaş & Düello Bildirimleri',
        channelDescription: 'Arkadaşlık istekleri, düello davetleri ve dürtme bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: 'ic_stat_notification',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

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
