import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../widgets/lucky_wheel_dialog.dart';
import 'achievement_service.dart';
import 'duel_ticket_service.dart';
import 'quest_service.dart';
import 'streak_service.dart';

/// Streak, çark, görev ve başarım durumunu `users/{uid}.gameState` altında
/// Firestore'a yazar; yeni cihazda / yeniden kurulumda yerel duruma geri yükler.
class CloudStateService {
  static DocumentReference<Map<String, dynamic>>? _userRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<void> save(String section, Map<String, dynamic> data) async {
    final ref = _userRef();
    if (ref == null) return;
    try {
      await ref.set({
        'gameState': {
          section: data,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CloudStateService.save($section) error: $e');
    }
  }

  static Future<void> restore() async {
    final ref = _userRef();
    if (ref == null) return;
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 4));
      final data = snap.data();
      if (data == null) return;
      final gameState = _asMap(data['gameState']);

      await StreakService.importState(_asMap(gameState['streak']));
      await LuckyWheelDialog.importState(_asMap(gameState['wheel']));
      await QuestService.importState(_asMap(gameState['quests']));
      await DuelTicketService.importState(_asMap(gameState['duelTickets']));
      await AchievementService.importState(
        unlocked: List<String>.from(data['unlockedBadges'] ?? const []),
        claimed: List<String>.from(data['claimedBadges'] ?? const []),
      );
    } catch (e) {
      debugPrint('CloudStateService.restore error: $e');
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
