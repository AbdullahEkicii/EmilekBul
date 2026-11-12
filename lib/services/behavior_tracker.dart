import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oyuncunun hangi özellikleri kullandığını cihazda tutan hafif davranış günlüğü.
///
/// Gizlilik: veri yalnızca bu cihazda, SharedPreferences'ta (~1 KB) tutulur; sunucuya gönderilmez.
/// Sabit bir özellik kümesi izlenir (serbest metin yok). Kullanıcı hatırlatmaları kapatınca
/// bildirim üretimi durur; veri ayrıca [reset] ile silinebilir.
///
/// Yapı:
/// - `f`: özellik -> { `n`: kullanım sayısı, `t`: son kullanım (ms) }
/// - `c`: kategori -> oyun sayısı (solo testlerde)
/// - `d`: son [maxPlayDays] oyun gününün tarihleri (yyyy-mm-dd), hafta içi saat dağılımı için `h`
class BehaviorTracker {
  static const String _key = 'behavior_v1';
  static const int maxPlayDays = 60;

  /// İzlenen özellik kümesi. Yeni özellik eklemek için buraya ekleyin.
  static const List<String> features = [
    'solo',
    'duel',
    'quick_match',
    'daily_challenge',
    'shop',
    'league',
    'friends',
    'share',
    'wheel',
  ];

  static Map<String, dynamic> _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return {'f': <String, dynamic>{}, 'c': <String, dynamic>{}, 'd': <String>[], 'h': <String, dynamic>{}};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {'f': <String, dynamic>{}, 'c': <String, dynamic>{}, 'd': <String>[], 'h': <String, dynamic>{}};
    }
  }

  /// Bir özelliğin kullanıldığını kaydeder. Bilinmeyen özellik sessizce yok sayılır.
  static Future<void> track(String feature, {String? category, DateTime? at}) async {
    if (!features.contains(feature)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final m = _load(prefs);
      final now = (at ?? DateTime.now());
      final f = Map<String, dynamic>.from(m['f'] as Map);
      final entry = Map<String, dynamic>.from((f[feature] as Map?) ?? {'n': 0, 't': 0});
      entry['n'] = ((entry['n'] as num?) ?? 0).toInt() + 1;
      entry['t'] = now.millisecondsSinceEpoch;
      f[feature] = entry;
      m['f'] = f;

      if (category != null && category.isNotEmpty) {
        final c = Map<String, dynamic>.from(m['c'] as Map);
        c[category] = ((c[category] as num?) ?? 0).toInt() + 1;
        m['c'] = c;
      }

      if (feature == 'solo' || feature == 'duel' || feature == 'daily_challenge') {
        final days = List<String>.from(m['d'] as List);
        final day = _ymd(now);
        if (!days.contains(day)) days.add(day);
        while (days.length > maxPlayDays) {
          days.removeAt(0);
        }
        m['d'] = days;
        final h = Map<String, dynamic>.from(m['h'] as Map);
        final hk = '${now.hour}';
        h[hk] = ((h[hk] as num?) ?? 0).toInt() + 1;
        m['h'] = h;
      }

      await prefs.setString(_key, jsonEncode(m));
    } catch (e) {
      debugPrint('BehaviorTracker.track error: $e');
    }
  }

  /// Ekranda/arka planda kullanılacak anlık özet (her çağrıda diskten okur, kısa ve ucuzdur).
  static Future<BehaviorSnapshot> snapshot({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    return BehaviorSnapshot.fromJson(_load(prefs), now ?? DateTime.now());
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Okunmuş davranış verisinin saf (test edilebilir) görünümü.
class BehaviorSnapshot {
  final Map<String, int> uses; // özellik -> kullanım sayısı
  final Map<String, int> lastUsedMs; // özellik -> son kullanım (ms)
  final Map<String, int> categoryPlays; // kategori -> oyun sayısı
  final List<String> playDays; // oyun günleri (yyyy-mm-dd)
  final Map<int, int> hourHistogram; // saat -> oyun sayısı
  final DateTime now;

  const BehaviorSnapshot({
    required this.uses,
    required this.lastUsedMs,
    required this.categoryPlays,
    required this.playDays,
    required this.hourHistogram,
    required this.now,
  });

  factory BehaviorSnapshot.fromJson(Map<String, dynamic> j, DateTime now) {
    final f = (j['f'] as Map?) ?? const {};
    final uses = <String, int>{};
    final last = <String, int>{};
    f.forEach((k, v) {
      final m = v as Map;
      uses[k as String] = (m['n'] as num?)?.toInt() ?? 0;
      last[k] = (m['t'] as num?)?.toInt() ?? 0;
    });
    final c = ((j['c'] as Map?) ?? const {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    final h = ((j['h'] as Map?) ?? const {})
        .map((k, v) => MapEntry(int.parse(k as String), (v as num).toInt()));
    return BehaviorSnapshot(
      uses: uses,
      lastUsedMs: last,
      categoryPlays: c,
      playDays: List<String>.from((j['d'] as List?) ?? const []),
      hourHistogram: h,
      now: now,
    );
  }

  int usesOf(String feature) => uses[feature] ?? 0;

  /// Hiç kullanılmamış özellikler (ilk tanıtım adayları).
  List<String> get neverUsed => BehaviorTracker.features.where((f) => usesOf(f) == 0).toList();

  /// Bir süredir (varsayılan 14 gün) kullanılmayan, daha önce kullanılmış özellikler.
  List<String> dormant({int days = 14}) {
    final cutoff = now.subtract(Duration(days: days)).millisecondsSinceEpoch;
    return BehaviorTracker.features
        .where((f) => usesOf(f) > 0 && (lastUsedMs[f] ?? 0) < cutoff)
        .toList();
  }

  /// En çok oynanan kategori (en az [minPlays] oyunla).
  String? favoriteCategory({int minPlays = 3}) {
    String? best;
    var bestN = 0;
    categoryPlays.forEach((k, v) {
      if (v >= minPlays && v > bestN) {
        best = k;
        bestN = v;
      }
    });
    return best;
  }

  /// Son [days] gün içinde kaç gün oynandı (bugün dahil).
  int playedDaysWithin(int days) {
    final from = now.subtract(Duration(days: days - 1));
    final set = <String>{};
    for (var i = 0; i < days; i++) {
      final d = from.add(Duration(days: i));
      set.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    return playDays.where(set.contains).length;
  }

  bool playedToday() => playDays.contains(
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');

  /// Oyuncunun en sık oyun saati (yoksa null).
  int? preferredHour() {
    if (hourHistogram.isEmpty) return null;
    final total = hourHistogram.values.fold<int>(0, (a, b) => a + b);
    if (total < 5) return null;
    return hourHistogram.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
