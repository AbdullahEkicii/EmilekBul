import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'analytics_service.dart';
import 'token_service.dart';

class League {
  final String id;
  final String emoji;
  final Color color;
  final int promotionReward;

  const League(this.id, this.emoji, this.color, this.promotionReward);

  String get titleKey => 'league.$id';
}

enum LeagueOutcome { promoted, demoted, stayed }

class LeagueResult {
  final League from;
  final League to;
  final LeagueOutcome outcome;
  final int rank;
  final int reward;

  const LeagueResult({
    required this.from,
    required this.to,
    required this.outcome,
    required this.rank,
    required this.reward,
  });
}

class LeagueEntry {
  final String uid;
  final String username;
  final String avatarIndex;
  final int weeklyPoints;

  const LeagueEntry(this.uid, this.username, this.avatarIndex, this.weeklyPoints);
}

/// Haftalık lig: puanlar `weekly_leagues/{hafta}_{lig}/scores/{uid}` altında tutulur.
/// Haftanın ilk açılışında önceki haftanın sıralamasına göre ilk %20 terfi eder, son %20 düşer.
class LeagueService {
  static const List<League> leagues = [
    League('bronze', '🥉', Color(0xFFCD7F32), 100),
    League('silver', '🥈', Color(0xFFC0C0C0), 200),
    League('gold', '🥇', Color(0xFFFFD700), 300),
    League('platinum', '💠', Color(0xFF67E8F9), 400),
    League('diamond', '💎', Color(0xFF818CF8), 0),
  ];

  static const double zoneRatio = 0.2;
  static const int minPlayersForDemotion = 5;

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static League leagueById(String? id) =>
      leagues.firstWhere((l) => l.id == id, orElse: () => leagues.first);

  /// ISO 8601 hafta anahtarı, ör. 2026-W39
  static String weekKey(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final week = (thursday.difference(firstDayOfYear).inDays ~/ 7) + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Bu haftanın bitimine (Pazartesi 00:00) kalan süre
  static Duration timeLeftInWeek() {
    final now = DateTime.now();
    final nextMonday = DateTime(now.year, now.month, now.day).add(Duration(days: 8 - now.weekday));
    return nextMonday.difference(now);
  }

  static CollectionReference<Map<String, dynamic>> _scores(String week, String leagueId) =>
      _db.collection('weekly_leagues').doc('${week}_$leagueId').collection('scores');

  static Future<League> getMyLeague() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return leagues.first;
    final doc = await _db.collection('users').doc(uid).get();
    return leagueById(doc.data()?['league'] as String?);
  }

  static Future<void> addWeeklyPoints(String uid, int points) async {
    if (points <= 0) return;
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final data = userDoc.data() ?? {};
      final league = leagueById(data['league'] as String?);
      await _scores(weekKey(DateTime.now()), league.id).doc(uid).set({
        'uid': uid,
        'username': data['username'],
        'avatarIndex': data['avatarIndex'],
        'weeklyPoints': FieldValue.increment(points),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('LeagueService.addWeeklyPoints error: $e');
    }
  }

  /// Yeni haftaya geçildiyse önceki haftayı değerlendirip ligi günceller.
  static Future<LeagueResult?> evaluateWeekIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final userRef = _db.collection('users').doc(uid);
      final data = (await userRef.get()).data() ?? {};
      final currentWeek = weekKey(DateTime.now());
      final lastWeek = data['leagueWeek'] as String?;
      final current = leagueById(data['league'] as String?);

      if (lastWeek == currentWeek) return null;
      if (lastWeek == null) {
        await userRef.set({'league': current.id, 'leagueWeek': currentWeek}, SetOptions(merge: true));
        return null;
      }

      final scores = _scores(lastWeek, current.id);
      final myDoc = await scores.doc(uid).get();
      final myPoints = (myDoc.data()?['weeklyPoints'] as num?)?.toInt() ?? 0;

      var outcome = LeagueOutcome.stayed;
      var rank = 0;
      if (myDoc.exists && myPoints > 0) {
        final total = (await scores.count().get()).count ?? 0;
        final higher = (await scores.where('weeklyPoints', isGreaterThan: myPoints).count().get()).count ?? 0;
        rank = higher + 1;
        final zoneSize = (total * zoneRatio).ceil().clamp(1, total);
        final index = leagues.indexOf(current);
        if (rank <= zoneSize && index < leagues.length - 1) {
          outcome = LeagueOutcome.promoted;
        } else if (total >= minPlayersForDemotion && rank > total - zoneSize && index > 0) {
          outcome = LeagueOutcome.demoted;
        }
      }

      final index = leagues.indexOf(current);
      final next = switch (outcome) {
        LeagueOutcome.promoted => leagues[index + 1],
        LeagueOutcome.demoted => leagues[index - 1],
        LeagueOutcome.stayed => current,
      };

      await userRef.set({'league': next.id, 'leagueWeek': currentWeek}, SetOptions(merge: true));

      final reward = outcome == LeagueOutcome.promoted ? current.promotionReward : 0;
      if (reward > 0) {
        await TokenService.addTokens(reward, source: 'league_promotion');
      }
      if (outcome != LeagueOutcome.stayed) {
        AnalyticsService.logCustomEvent(
          name: 'league_${outcome.name}',
          parameters: {'from': current.id, 'to': next.id, 'rank': rank},
        );
      }
      return LeagueResult(from: current, to: next, outcome: outcome, rank: rank, reward: reward);
    } catch (e) {
      debugPrint('LeagueService.evaluateWeekIfNeeded error: $e');
      return null;
    }
  }

  static Future<List<LeagueEntry>> getLeaderboard(League league, {int limit = 30}) async {
    final snap = await _scores(weekKey(DateTime.now()), league.id)
        .orderBy('weeklyPoints', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return LeagueEntry(
        d.id,
        data['username']?.toString() ?? '',
        data['avatarIndex']?.toString() ?? '',
        (data['weeklyPoints'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  static Future<int> getParticipantCount(League league) async {
    final snap = await _scores(weekKey(DateTime.now()), league.id).count().get();
    return snap.count ?? 0;
  }
}
