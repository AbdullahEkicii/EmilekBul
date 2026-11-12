import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import 'analytics_service.dart';

enum ReportResult { sent, limitReached, failed }

/// Oyuncuların hatalı/yanıltıcı soruları bildirmesi — **Firestore kuralı değişikliği gerektirmez**.
///
/// Bildirimin gerçek etkileri:
/// 1) **Yerel:** bildirilen soru bu oyuncuya bir daha gösterilmez (yerel/bulut/önbellek sonuçları filtrelenir).
/// 2) **Ortak havuz:** mevcut kurallarla izin verilen `question_bank/.../questions/{id}` dokümanına
///    `reports` sayacı artırılır (en iyi çaba). Sayaç [flagThreshold]'a ulaşan sorular havuzdan
///    herkese gösterilmez → topluluk kendi kalitesini denetler.
/// Günde en fazla [dailyLimit] bildirim; aynı soru için sayaç yalnızca bir kez artırılır.
class QuestionReportService {
  static const int dailyLimit = 10;
  static const int flagThreshold = 3;
  static const int _maxLocalKeys = 300;

  static const String _dateKey = 'qreport_date';
  static const String _countKey = 'qreport_count';
  static const String _keysKey = 'qreport_keys';

  /// Havuz doküman kimliği ve soru eşleştirmesi için aynı normalizasyon (QuestionPoolService ile aynı).
  static String normalize(String q) =>
      q.toLowerCase().replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]'), '').trim();

  static bool isCommunityFlagged(Map<String, dynamic> data) =>
      ((data['reports'] as num?)?.toInt() ?? 0) >= flagThreshold;

  static Future<Set<String>> reportedKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_keysKey) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Bildirilmiş soruları listeden çıkarır.
  static List<Question> filterReported(List<Question> list, Set<String> reported) {
    if (reported.isEmpty) return list;
    return list.where((q) => !reported.contains(normalize(q.question))).toList();
  }

  static Future<ReportResult> submit({
    required String question,
    required String category,
    required String difficulty,
    required String reason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final used = prefs.getString(_dateKey) == today ? (prefs.getInt(_countKey) ?? 0) : 0;
      if (used >= dailyLimit) return ReportResult.limitReached;

      final key = normalize(question);
      if (key.isEmpty) return ReportResult.failed;

      final keys = (prefs.getStringList(_keysKey) ?? <String>[]);
      final alreadyReported = keys.contains(key);
      if (!alreadyReported) {
        keys.add(key);
        if (keys.length > _maxLocalKeys) keys.removeRange(0, keys.length - _maxLocalKeys);
        await prefs.setStringList(_keysKey, keys); // yerel etki hemen geçerli
      }
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, used + 1);

      // Ortak havuz sayacı (en iyi çaba; başarısızlık kullanıcıyı ilgilendirmez)
      var remote = false;
      if (!alreadyReported && FirebaseAuth.instance.currentUser != null) {
        remote = await _bumpPoolCounter(question, category, difficulty, reason);
      }
      AnalyticsService.logCustomEvent(
          name: 'question_reported', parameters: {'reason': reason, 'remote': remote ? 1 : 0});
      return ReportResult.sent;
    } catch (e) {
      debugPrint('QuestionReportService.submit error: $e');
      return ReportResult.failed;
    }
  }

  static Future<bool> _bumpPoolCounter(
      String question, String category, String difficulty, String reason) async {
    try {
      final partitionKey = '${category}_$difficulty'.replaceAll('/', '_');
      final docId = 'q_${category.hashCode.abs()}_${normalize(question).hashCode.abs()}';
      await FirebaseFirestore.instance
          .collection('question_bank')
          .doc(partitionKey)
          .collection('questions')
          .doc(docId)
          .update({
        'reports': FieldValue.increment(1),
        'reportReasons.$reason': FieldValue.increment(1),
      }).timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      // Doküman havuzda yoksa (yerel/çevrimdışı soru) veya ağ yoksa sessizce geç
      debugPrint('Pool report counter skipped: $e');
      return false;
    }
  }
}
