import 'analytics_service.dart';
import 'token_service.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import 'database_helper.dart';
import 'question_report_service.dart';

/// Uyarlanabilir zorluk (Elo tabanlı DDA) ve kişisel öneri.
///
/// Model:
/// - Her oyuncu için kategori başına Elo benzeri bir beceri puanı tutulur.
/// - Her soru için bir zorluk puanı tutulur (yerel SQLite `question_stats`).
/// - Beklenen başarı, 4 şıklı soru için şans düzeltmeli Elo formülüyle hesaplanır:
///   p = 0.25 + 0.75 * 1 / (1 + 10^((zorluk - beceri)/400))
/// - Her cevapta hem oyuncu hem soru puanı güncellenir (klasik Elo).
///
/// Kullanım:
/// - [recordAnswer]: tekli testte her cevapta (atlanan/süre dolan sorular kaydedilmez).
/// - [arrange]: test başlamadan önce sorular aynı kümeden, kolaydan zora doğru sıralanır.
///   Kümeyi değiştirmez; yalnızca sırayı düzenler. Hata olursa orijinal liste döner.
/// - [weakestTopic] / [recommendedDifficulty]: "zayıf konu" modu için öneri.
///
/// Sınırlar: tüm veri cihazda tutulur (sunucuda doğrulanmaz). Sayılar yeterli veri
/// olmadan güvenilir değildir; bu yüzden zayıf konu önerisi en az [minAnswersForWeak] cevap ister.
class AdaptiveService {
  static const double baseRating = 1000;
  static const double kPlayer = 24;
  static const double kQuestion = 16;
  static const double chance = 0.25; // 4 şık
  static const int minAnswersForWeak = 10;
  static const String _profileKey = 'adaptive_v1';

  /// Ustalık seviyesi ödülü: seviye × 25 jeton.
  static int masteryReward(int level) => level * 25;

  // ------------------------------------------------------------ profil (prefs)
  static Future<_Profile> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw == null) return _Profile.empty();
      return _Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _Profile.empty();
    }
  }

  static Future<void> _saveProfile(_Profile p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, jsonEncode(p.toJson()));
    } catch (e) {
      debugPrint('AdaptiveService save error: $e');
    }
  }

  // ------------------------------------------------------------ matematik
  /// Şans düzeltmeli beklenen başarı olasılığı.
  static double expected(double playerRating, double questionDifficulty) {
    final raw = 1 / (1 + pow(10, (questionDifficulty - playerRating) / 400));
    return chance + (1 - chance) * raw;
  }

  /// Zorluk etiketinden başlangıç puanı (soru ilk kez görülürken).
  static double initialDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Kolay':
        return 900;
      case 'Zor':
        return 1100;
      case 'İmkansız':
      case 'Imkansız':
        return 1200;
      default:
        return 1000;
    }
  }

  static String _key(String question) => QuestionReportService.normalize(question);

  // ------------------------------------------------------------ kayıt
  /// Tekli testte bir soru cevaplandığında çağrılır. Atlanan soru veya süre dolumu için çağırmayın.
  static Future<void> recordAnswer({
    required String question,
    required String category,
    required String difficulty,
    required bool correct,
  }) async {
    try {
      final key = _key(question);
      if (key.isEmpty) return;
      final profile = await _loadProfile();
      final playerRating = profile.rating(category);

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('question_stats',
          columns: ['difficulty', 'shown', 'correct'], where: 'qkey = ?', whereArgs: [key], limit: 1);
      final qDiff = rows.isEmpty
          ? initialDifficulty(difficulty)
          : (rows.first['difficulty'] as num).toDouble();
      final e = expected(playerRating, qDiff);
      final s = correct ? 1.0 : 0.0;

      final newPlayer = playerRating + kPlayer * (s - e);
      final newDiff = qDiff + kQuestion * (e - s); // oyuncu yanıldıysa soru zorlaşır

      await db.insert(
        'question_stats',
        {
          'qkey': key,
          'category': category,
          'shown': (rows.isEmpty ? 0 : (rows.first['shown'] as int)) + 1,
          'correct': (rows.isEmpty ? 0 : (rows.first['correct'] as int)) + (correct ? 1 : 0),
          'difficulty': newDiff,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final before = MasteryInfo.from(category, profile.answersFor(category), profile.correctFor(category)).level;
      profile.setRating(category, newPlayer);
      profile.addAnswer(category, correct);
      final after = MasteryInfo.from(category, profile.answersFor(category), profile.correctFor(category)).level;
      await _saveProfile(profile);

      // Seviye atlayınca bir kez ödül (aynı seviye tekrar ödüllendirilmez; seviye düşüp çıkarsa da tekrar verilmez)
      if (after > before && after > profile.rewardedLevel(category)) {
        profile.setRewardedLevel(category, after);
        await _saveProfile(profile);
        final reward = masteryReward(after);
        await TokenService.addTokens(reward, source: 'mastery');
        AnalyticsService.logCustomEvent(
            name: 'mastery_level_up', parameters: {'level': after, 'tokens': reward});
      }
    } catch (e) {
      debugPrint('AdaptiveService.recordAnswer error: $e');
    }
  }

  // ------------------------------------------------------------ sıralama (DDA)
  /// Sorular kolaydan zora doğru yerleşir: başta başarı olasılığı ~%85, sonda ~%50 hedeflenir.
  /// Küme değişmez, yalnızca sıra değişir. Hata olursa orijinal liste döner.
  static Future<List<Question>> arrange(
    List<Question> questions, {
    required String category,
    required String difficulty,
  }) async {
    try {
      final n = questions.length;
      if (n < 3) return questions;
      final profile = await _loadProfile();
      final rating = profile.rating(category);

      final keys = questions.map((q) => _key(q.question)).toList();
      final db = await DatabaseHelper.instance.database;
      final known = <String, double>{};
      for (var i = 0; i < keys.length; i += 200) {
        final chunk = keys.sublist(i, min(i + 200, keys.length));
        final rows = await db.query('question_stats',
            columns: ['qkey', 'difficulty'],
            where: 'qkey IN (${List.filled(chunk.length, '?').join(',')})',
            whereArgs: chunk);
        for (final r in rows) {
          known[r['qkey'] as String] = (r['difficulty'] as num).toDouble();
        }
      }

      final start = initialDifficulty(difficulty);
      final pool = <_Scored>[
        for (var i = 0; i < n; i++)
          _Scored(questions[i], expected(rating, known[keys[i]] ?? start)),
      ];

      final ordered = <Question>[];
      for (var pos = 0; pos < n; pos++) {
        // Hedef başarı: başta kolay (0.85), sonda orta (0.50)
        final target = 0.85 - 0.35 * (n == 1 ? 0 : pos / (n - 1));
        var best = 0;
        var bestGap = double.infinity;
        for (var j = 0; j < pool.length; j++) {
          final gap = (pool[j].p - target).abs();
          if (gap < bestGap) {
            bestGap = gap;
            best = j;
          }
        }
        ordered.add(pool.removeAt(best).q);
      }
      return ordered;
    } catch (e) {
      debugPrint('AdaptiveService.arrange error: $e');
      return questions;
    }
  }

  // ------------------------------------------------------------ öneri ve ustalık
  /// Tüm kategorilerin özeti (ustalık seviyesi ve doğruluk).
  static Future<List<MasteryInfo>> summaries() async {
    final profile = await _loadProfile();
    return profile.answers.entries
        .map((e) => MasteryInfo.from(e.key, e.value, profile.correctFor(e.key)))
        .toList()
      ..sort((a, b) => b.answers.compareTo(a.answers));
  }

  /// En düşük doğruluklu kategori (yeterli cevap sayısı olanlar arasından).
  static Future<MasteryInfo?> weakestTopic() async {
    final list = (await summaries()).where((m) => m.answers >= minAnswersForWeak).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return list.first;
  }

  /// Oyuncunun kategorideki beceri puanına göre önerilen zorluk.
  static Future<String> recommendedDifficulty(String category) async {
    final profile = await _loadProfile();
    final r = profile.rating(category);
    if (r < 1000) return 'Kolay';
    if (r < 1150) return 'Orta';
    return 'Zor';
  }
}

class _Scored {
  final Question q;
  final double p;
  const _Scored(this.q, this.p);
}

class _Profile {
  final Map<String, double> ratings;
  final Map<String, int> answers;
  final Map<String, int> correct;
  final Map<String, int> rewarded; // kategori -> ödüllendirilen en yüksek ustalık seviyesi

  _Profile(this.ratings, this.answers, this.correct, this.rewarded);

  factory _Profile.empty() => _Profile({}, {}, {}, {});

  factory _Profile.fromJson(Map<String, dynamic> j) => _Profile(
        (j['r'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        (j['n'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
        (j['c'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
        (j['lv'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );

  Map<String, dynamic> toJson() => {'r': ratings, 'n': answers, 'c': correct, 'lv': rewarded};

  int rewardedLevel(String category) => rewarded[category] ?? 0;
  void setRewardedLevel(String category, int level) => rewarded[category] = level;
  int answersFor(String category) => answers[category] ?? 0;

  double rating(String category) => ratings[category] ?? AdaptiveService.baseRating;
  void setRating(String category, double v) => ratings[category] = v;
  void addAnswer(String category, bool isCorrect) {
    answers[category] = (answers[category] ?? 0) + 1;
    if (isCorrect) correct[category] = (correct[category] ?? 0) + 1;
  }

  int correctFor(String category) => correct[category] ?? 0;
}

/// Kategori ustalığı. Seviye, cevap sayısı ve doğruluk birlikte belirler (0 = yeni).
class MasteryInfo {
  final String category;
  final int answers;
  final int correct;

  const MasteryInfo(this.category, this.answers, this.correct);

  factory MasteryInfo.from(String category, int answers, int correct) =>
      MasteryInfo(category, answers, correct);

  double get accuracy => answers == 0 ? 0 : correct / answers;

  /// 0: yeni (<10) · 1: başlangıç · 2: gelişiyor (%50+) · 3: uzman (50+ cevap, %65+) ·
  /// 4: usta (150+, %75+) · 5: efsane (300+, %85+)
  int get level {
    if (answers < AdaptiveService.minAnswersForWeak) return 0;
    if (answers >= 300 && accuracy >= 0.85) return 5;
    if (answers >= 150 && accuracy >= 0.75) return 4;
    if (answers >= 50 && accuracy >= 0.65) return 3;
    if (accuracy >= 0.5) return 2;
    return 1;
  }
}
