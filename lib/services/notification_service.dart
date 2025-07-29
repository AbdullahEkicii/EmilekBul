import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Hizmeti başlatır: bildirim kanallarını ayarlar ve zaman dilimini başlatır.
  static Future<void> init() async {
    // Zaman dilimi başlat
    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android için başlatma ayarları
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    // Bildirim eklentisini başlat
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (payload) {
        // Bildirime tıklanınca yapılacak işlem
      },
    );

    // 🔥 Android'de kanal oluştur
    const AndroidNotificationChannel reminderChannel =
        AndroidNotificationChannel(
      'reminder_channel',
      'Hatırlatıcılar',
      description: 'AI soru hatırlatmaları ve günlük bildirimler',
      importance: Importance.high,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(reminderChannel);
    // Zaman dilimi verilerini başlat (zonedSchedule için gerekli)
    tzData.initializeTimeZones();
  }

  /// Günlük saat 12:00'de ödül bildirimi planlar.
  static Future<void> showDailyRewardNotification() async {
    await _notifications.zonedSchedule(
      0, // bildirim ID'si
      '🎁 Günlük Ödül',
      'Günlük ödülünüz hazır! Gelin ve alın!',
      _nextInstanceOfNoon(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          'Günlük Bildirimler',
          importance: Importance.max,
          priority: Priority.high,
          channelShowBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Rastgele bir saatte AI sorusu hatırlatma bildirimi planlar.
  static Future<void> showAiQuestionReminderNotification(int id) async {
    await _notifications.zonedSchedule(
      id,
      '🤖 Yeni Sorular Var!',
      'Yapay zekanın bugünkü sorularını görmek ister misin?',
      _randomTimeToday(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Hatırlatıcılar',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Bugünün 12:00'ini döner, geçmişse yarınki tarihi verir.
  static tz.TZDateTime _nextInstanceOfNoon() {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 12, 0);
    return scheduled.isBefore(now)
        ? scheduled.add(const Duration(days: 1))
        : scheduled;
  }

  /// Bugün veya yarın rastgele bir saatte bildirim zamanlar.
  static tz.TZDateTime _randomTimeToday() {
    final now = tz.TZDateTime.now(tz.local);
    final hours = [10, 15, 18, 20]..shuffle();
    final hour = hours.first;

    final scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    return scheduled.isBefore(now)
        ? scheduled.add(const Duration(days: 1))
        : scheduled;
  }

  /// TEST: 30 saniye sonra AI soru hatırlatması
  static Future<void> testAiReminderIn30Seconds() async {
    print('merhaba');
    await _notifications.show(
      997,
      '🤖 Yeni Sorular Var!',
      'AI soruları seni bekliyor!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Hatırlatıcılar',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Tekrarlanan bildirimler için günlük ödül bildirimi planlar
  static Future<void> scheduleDailyRewardNotification() async {
    await _notifications.zonedSchedule(
      0,
      '🎁 Günlük Ödül',
      'Günlük ödülünüz her gün yenilenir! Almayı unutmayın.',
      _nextInstanceOfNoon(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          'Günlük Bildirimler',
          importance: Importance.max,
          priority: Priority.high,
          channelShowBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    // Günlük tekrar için bir sonraki gün de planla
    _scheduleNextDay();
  }

  /// Bir sonraki günün bildirimini planlar (tekrarlayan bildirimler için)
  static void _scheduleNextDay() {
    Future.delayed(const Duration(days: 1), () async {
      await scheduleDailyRewardNotification();
    });
  }

  /// Tüm planlı bildirimleri temizler (test amaçlı veya sıfırlama için)
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
