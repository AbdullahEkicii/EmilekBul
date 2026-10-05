import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_categories.dart';
import '../models/question.dart';
import 'analytics_service.dart';
import 'question_pool_service.dart';
import 'token_service.dart';
import 'user_service.dart';

class DailyChallengeResult {
  final int correct;
  final int total;
  final int timeMs;
  final List<bool> pattern;

  const DailyChallengeResult({
    required this.correct,
    required this.total,
    required this.timeMs,
    required this.pattern,
  });

  factory DailyChallengeResult.fromMap(Map<String, dynamic> m) => DailyChallengeResult(
        correct: (m['correct'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 5,
        timeMs: (m['timeMs'] as num?)?.toInt() ?? 0,
        pattern: List<bool>.from((m['pattern'] as List?) ?? const []),
      );
}

class DailyChallengeEntry {
  final String uid;
  final String username;
  final String avatarIndex;
  final int correct;
  final int timeMs;

  const DailyChallengeEntry(this.uid, this.username, this.avatarIndex, this.correct, this.timeMs);
}

/// Günün Testi: aynı gün aynı dildeki herkes aynı 5 soruyu çözer; tek hak, günlük sıralama.
/// Sorular günün ilk oyuncusunun cihazında bir kez üretilip `daily_challenge/{tarih}_{dil}` altına yazılır.
class DailyChallengeService {
  static const int questionCount = 5;
  static const int tokensPerCorrect = 5;
  static const String difficulty = 'Orta';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /// Günün kategorisi tarihe göre döner (tüm dillerde aynı).
  static String todayCategory() {
    final now = DateTime.now();
    final dayIndex = DateTime(now.year, now.month, now.day).difference(DateTime(2024)).inDays;
    final categories = AppCategories.categories;
    return categories[dayIndex % categories.length].name;
  }

  static DocumentReference<Map<String, dynamic>> _doc(String lang) =>
      _db.collection('daily_challenge').doc('${todayKey()}_$lang');

  static Future<List<Question>> getOrCreateQuestions(String lang) async {
    final ref = _doc(lang);
    final existing = await ref.get();
    if (existing.exists) return _parse(existing.data());

    final generated = await QuestionPoolService.getHybridQuestions(
      category: todayCategory(),
      difficulty: difficulty,
      languageCode: lang,
      count: questionCount,
      includeSpacedRepetition: false,
    );
    if (generated.length < questionCount) {
      throw Exception('Not enough questions for daily challenge');
    }

    // Aynı anda başka bir oyuncu da ürettiyse ilk yazılanı kullan
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return _parse(snap.data());
      final questions = generated.take(questionCount).toList();
      tx.set(ref, {
        'date': todayKey(),
        'lang': lang,
        'category': todayCategory(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return questions;
    });
  }

  static List<Question> _parse(Map<String, dynamic>? data) {
    final raw = (data?['questions'] as List?) ?? const [];
    return raw.whereType<Map>().map((m) => Question.fromJson(m)).toList();
  }

  static Future<DailyChallengeResult?> getMyResult(String lang) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _doc(lang).collection('scores').doc(uid).get();
    if (!snap.exists) return null;
    return DailyChallengeResult.fromMap(snap.data()!);
  }

  /// Sonucu kaydeder (günde tek hak) ve ödülü verir. Zaten oynandıysa false döner.
  static Future<bool> submit({
    required String lang,
    required List<bool> pattern,
    required int timeMs,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final ref = _doc(lang).collection('scores').doc(uid);
    final correct = pattern.where((c) => c).length;
    try {
      final profile = await UserService.getUserProfile(uid);
      await ref.set({
        'uid': uid,
        'username': profile?['username'],
        'avatarIndex': profile?['avatarIndex'],
        'correct': correct,
        'total': pattern.length,
        'timeMs': timeMs,
        'pattern': pattern,
        // Tek alanlı sıralama: önce doğru sayısı, eşitlikte daha kısa süre
        'rankScore': correct * 10000000 - timeMs.clamp(0, 9999999),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Kurallar tekrar yazmayı engeller: bugün zaten oynanmış
      debugPrint('Daily challenge submit error: $e');
      return false;
    }

    final reward = correct * tokensPerCorrect;
    if (reward > 0) await TokenService.addTokens(reward, source: 'daily_challenge');
    try {
      await UserService.addPointsToUser(
        uid: uid,
        category: todayCategory(),
        pointsToAdd: correct * 2,
        difficulty: difficulty,
      );
    } catch (_) {}
    AnalyticsService.logCustomEvent(name: 'daily_challenge_complete', parameters: {'correct': correct, 'time_ms': timeMs});
    return true;
  }

  static Future<List<DailyChallengeEntry>> leaderboard(String lang, {int limit = 20}) async {
    final snap = await _doc(lang).collection('scores').orderBy('rankScore', descending: true).limit(limit).get();
    return snap.docs.map((d) {
      final m = d.data();
      return DailyChallengeEntry(
        d.id,
        m['username']?.toString() ?? '',
        m['avatarIndex']?.toString() ?? '',
        (m['correct'] as num?)?.toInt() ?? 0,
        (m['timeMs'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  /// (sıra, toplam katılımcı)
  static Future<(int, int)> myRank(String lang, DailyChallengeResult result) async {
    final scores = _doc(lang).collection('scores');
    final myScore = result.correct * 10000000 - result.timeMs.clamp(0, 9999999);
    final total = (await scores.count().get()).count ?? 0;
    final higher = (await scores.where('rankScore', isGreaterThan: myScore).count().get()).count ?? 0;
    return (higher + 1, total);
  }

  /// Wordle tarzı paylaşım metni: 🟩🟥 dizisi
  static String patternEmoji(List<bool> pattern) => pattern.map((c) => c ? '🟩' : '🟥').join();
}
