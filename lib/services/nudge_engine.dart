import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_categories.dart';
import 'adaptive_service.dart';
import 'behavior_tracker.dart';
import 'retention_engine.dart';
import 'retention_scheduler.dart';

/// Davranışa dayalı kişisel bildirim ve "henüz denemediğin" önerileri.
///
/// Kurallar (kullanıcı güveni ve Play politikası için):
/// - Hatırlatmalar kapalıysa hiçbir şey planlanmaz (ayarla birlikte kapanır).
/// - Günde en fazla 1 bildirim; haftada en fazla [weeklyCap].
/// - Bugün oynayan oyuncuya o gün bildirim gitmez (zaten ilgili).
/// - Her aday kendi bekleme süresine (cooldown) tabidir; aynı mesaj tekrar etmez.
/// - Metinler gerçek veriye dayanır ("3 gün kaldı", "%21 doğruluk"); sahte aciliyet yok.
/// - Bildirim saati oyuncunun en sık oyun saatine göre; yoksa 19:00. Sessiz saatler (22–08) dışında.
class NudgeEngine {
  static const int nudgeId = 810;
  static const int weeklyCap = 4;
  static const String _planKey = 'nudge_plan_v1';
  static const String _sentKey = 'nudge_sent_v1'; // id -> yyyy-mm-dd (son gönderilen gün)
  static const String _sentDaysKey = 'nudge_sent_days_v1';
  static const String _textsKey = 'nudge_texts_v1';

  static const Map<String, int> cooldownDays = {
    'weekly': 1,
    'fav': 2,
    'weak': 3,
    'dormant': 7,
    'never': 3,
    'lapsed': 2,
  };

  // ------------------------------------------------------------------ saf karar
  /// Tüm giriş verisi dışarıdan verilir: test edilebilir, yan etkisiz.
  static NudgeChoice? choose(NudgeInput input) {
    final snap = input.snap;
    if (snap.playedToday()) return null; // bugün zaten oynadı
    if (input.sentDays.length >= weeklyCap) return null;

    bool ok(String id) {
      final last = input.lastSent[id];
      if (last == null) return true;
      final gap = _daysBetween(last, input.date);
      return gap >= (cooldownDays[id] ?? 1);
    }

    // 1) Haftalık sandık yaklaşıyor (gerçek ilerleme)
    if (!input.weeklyClaimed && input.weeklyDays >= 2 && input.weeklyDays < 4 && ok('weekly')) {
      return NudgeChoice('weekly', ['${4 - input.weeklyDays}']);
    }
    // 2) Uzun süredir oynamayan: geri çağırma önce gelir (yeni özellik önerisinden önce)
    final lastAny = snap.lastUsedMs.values.fold<int>(0, (a, b) => b > a ? b : a);
    if (lastAny > 0 && ok('lapsed')) {
      final days = DateTime.fromMillisecondsSinceEpoch(lastAny)
          .difference(snap.now)
          .inDays
          .abs();
      if (days >= 3) return NudgeChoice('lapsed', const []);
    }
    // 3) Favori kategoride devam (gerçek oyun geçmişinden)
    final fav = snap.favoriteCategory();
    if (fav != null && ok('fav')) {
      return NudgeChoice('fav', [fav]);
    }
    // 4) Zayıf konu (yeterli cevap sayısından sonra)
    if (input.weakTopic != null && ok('weak')) {
      return NudgeChoice('weak', [input.weakTopic!, '${input.weakPct}']);
    }
    // 5) Bir süredir kullanılmayan, daha önce denenmiş özellik
    final dormant = snap.dormant();
    if (dormant.isNotEmpty && ok('dormant')) {
      return NudgeChoice('dormant', [dormant.first]);
    }
    // 6) Hiç denenmemiş özellik (gün sırasıyla döner; tek seferde bir tane)
    final never = snap.neverUsed.where(discoverable.contains).toList();
    if (never.isNotEmpty && ok('never')) {
      final pick = never[_dayOrdinal(input.date) % never.length];
      return NudgeChoice('never', [pick]);
    }
    return null;
  }

  /// Keşif kartı ve "denemediğin" bildirimleri için uygun özellikler (tek tıkla açılabilenler).
  static const List<String> discoverable = [
    'quick_match',
    'daily_challenge',
    'shop',
    'league',
    'friends',
    'wheel',
  ];

  static int _dayOrdinal(String ymd) {
    final d = DateTime.parse(ymd);
    return d.difference(DateTime(2024)).inDays;
  }

  static int _daysBetween(String a, String b) =>
      DateTime.parse(b).difference(DateTime.parse(a)).inDays;

  // ------------------------------------------------------------------ zamanlama
  /// Bildirim saati: en sık oyun saati (9–20 aralığına sıkıştırılmış), yoksa 19.
  static int preferredHour(BehaviorSnapshot snap) {
    final h = snap.preferredHour() ?? 19;
    return h.clamp(9, 20);
  }

  /// Bir sonraki uygun zamanı (bugün veya yarın) hesaplar; dakika 7–46 arası (:00 kümelenmesini önler).
  static DateTime nextSlot(DateTime now, int hour, {required int minuteSeed}) {
    final minute = 7 + (minuteSeed % 40);
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now.add(const Duration(minutes: 30)))) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  // ------------------------------------------------------------------ çalıştırma
  /// Worker ya da uygulama açılışında çağrılır. Bugünkü planı korur, yoksa yeniden hesaplar.
  static Future<void> evaluate({bool fromWorker = false, DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fromWorker) await prefs.reload();
      if (!(prefs.getBool(RetentionScheduler.kReminders) ?? true)) {
        await _cancel(fromWorker);
        return;
      }
      await RetentionScheduler.ensureTz();
      final current = now ?? DateTime.now();
      final snap = await BehaviorTracker.snapshot(now: current);

      if (snap.playedToday()) {
        await _cancel(fromWorker);
        return;
      }

      final date = RetentionScheduler.ymd(current);
      final lastSentMap = _readMap(prefs, _sentKey);
      final sentDays = _readList(prefs, _sentDaysKey)
          .where((d) => _daysBetween(d, date) < 7)
          .toList();

      final weekly = await RetentionEngine.getWeekly();
      final weak = await AdaptiveService.weakestTopic();
      final cats = await _loadCatNames(prefs);

      final choice = choose(NudgeInput(
        snap: snap,
        date: date,
        weeklyDays: weekly.$1,
        weeklyClaimed: weekly.$2,
        weakTopic: weak == null ? null : (cats[weak.category] ?? weak.category),
        weakPct: weak == null ? 0 : (weak.accuracy * 100).round(),
        lastSent: lastSentMap,
        sentDays: sentDays,
      ));

      final hour = preferredHour(snap);
      final slot = nextSlot(current, hour, minuteSeed: _dayOrdinal(date));
      final slotDate = RetentionScheduler.ymd(slot);

      if (choice == null) {
        await _cancel(fromWorker);
        return;
      }

      final texts = _readTexts(prefs);
      final t = texts[choice.id];
      if (t == null) return; // metin önbelleği yok: önce uygulama açılmalı
      // Argümanları yerelleştir: özellik anahtarı -> ad, kategori adı -> yerel ad
      final args = choice.args.map((a) {
        if (choice.id == 'dormant' || choice.id == 'never') return _featureFromPrefs(prefs, a);
        if (choice.id == 'fav') return cats[a] ?? a;
        return a;
      }).toList();
      final title = _fill(t['t'] as String, args);
      final body = _fill(t['b'] as String, args);

      final plugin = FlutterLocalNotificationsPlugin();
      if (fromWorker) {
        await plugin.initialize(const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ));
      }
      await plugin.cancel(nudgeId);
      final when = tz.TZDateTime(tz.local, slot.year, slot.month, slot.day, slot.hour, slot.minute);
      await plugin.zonedSchedule(
        nudgeId,
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_channel',
            'Daily reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'nudge_${choice.id}',
      );

      // Planı ve gönderim kaydını yaz (aynı gün tekrar hesaplanmasın, bekleme süresi işlesin)
      await prefs.setString(_planKey, jsonEncode({'date': slotDate, 'id': choice.id}));
      lastSentMap[choice.id] = slotDate;
      await prefs.setString(_sentKey, jsonEncode(lastSentMap));
      sentDays.add(slotDate);
      await prefs.setString(_sentDaysKey, jsonEncode(sentDays));
    } catch (e) {
      debugPrint('NudgeEngine.evaluate error: $e');
    }
  }

  static Future<void> _cancel(bool fromWorker) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (fromWorker) {
        await plugin.initialize(const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ));
      }
      await plugin.cancel(nudgeId);
    } catch (_) {}
  }

  // ------------------------------------------------------------------ metin önbelleği
  /// Uygulama açıkken (dil doğru iken) bildirim şablonlarını ve kategori/özellik adlarını kaydeder.
  static Future<void> cacheTexts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templates = <String, Map<String, String>>{
        'weekly': {'t': 'nudge.weekly_title'.tr(), 'b': 'nudge.weekly_body'.tr()},
        'fav': {'t': 'nudge.fav_title'.tr(), 'b': 'nudge.fav_body'.tr()},
        'weak': {'t': 'nudge.weak_title'.tr(), 'b': 'nudge.weak_body'.tr()},
        'dormant': {'t': 'nudge.dormant_title'.tr(), 'b': 'nudge.dormant_body'.tr()},
        'never': {'t': 'nudge.never_title'.tr(), 'b': 'nudge.never_body'.tr()},
        'lapsed': {'t': 'nudge.lapsed_title'.tr(), 'b': 'nudge.lapsed_body'.tr()},
      };
      final feats = <String, String>{
        for (final f in BehaviorTracker.features) f: 'nudge.feat_$f'.tr(),
      };
      final cats = <String, String>{
        for (final c in AppCategories.categories) c.name: c.key.tr(),
      };
      await prefs.setString(_textsKey, jsonEncode({'tpl': templates, 'feat': feats, 'cats': cats}));
    } catch (e) {
      debugPrint('NudgeEngine.cacheTexts error: $e');
    }
  }

  static Map<String, Map<String, dynamic>> _readTexts(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_textsKey);
      if (raw == null) return {};
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return (m['tpl'] as Map).map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _loadCatNames(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_textsKey);
      if (raw == null) return {};
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return Map<String, String>.from(m['cats'] as Map);
    } catch (_) {
      return {};
    }
  }

  static String _featureFromPrefs(SharedPreferences prefs, String feature) {
    try {
      final raw = prefs.getString(_textsKey);
      if (raw == null) return feature;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final f = (m['feat'] as Map?)?[feature];
      return f is String ? f : feature;
    } catch (_) {
      return feature;
    }
  }

  /// Keşif kartı için yerelleştirilmiş özellik adı.
  static Future<String> featureLabel(String feature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_textsKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final f = (m['feat'] as Map?)?[feature];
        if (f is String) return f;
      }
    } catch (_) {}
    return 'nudge.feat_$feature'.tr();
  }

  static String _fill(String template, List<String> args) {
    var out = template;
    for (final a in args) {
      final i = out.indexOf('{}');
      if (i < 0) break;
      out = out.replaceRange(i, i + 2, a);
    }
    return out;
  }

  static Map<String, String> _readMap(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return {};
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static List<String> _readList(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }
}

class NudgeChoice {
  final String id;
  final List<String> args;
  const NudgeChoice(this.id, this.args);
}

/// Karar fonksiyonunun girişi: tüm dış durumlar dışarıdan verilir.
class NudgeInput {
  final BehaviorSnapshot snap;
  final String date; // yyyy-mm-dd
  final int weeklyDays;
  final bool weeklyClaimed;
  final String? weakTopic;
  final int weakPct;
  final Map<String, String> lastSent;
  final List<String> sentDays;

  const NudgeInput({
    required this.snap,
    required this.date,
    required this.weeklyDays,
    required this.weeklyClaimed,
    this.weakTopic,
    this.weakPct = 0,
    this.lastSent = const {},
    this.sentDays = const [],
  });
}
