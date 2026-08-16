import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/duel_room_model.dart';
import 'user_service.dart';

class DuelInvite {
  final String id;
  final String fromUid;
  final String fromUsername;
  final String fromAvatar;
  final String roomCode;
  final String category;
  final String difficulty;
  final int betTokens;
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'rejected'

  DuelInvite({
    required this.id,
    required this.fromUid,
    required this.fromUsername,
    required this.fromAvatar,
    required this.roomCode,
    required this.category,
    required this.difficulty,
    required this.betTokens,
    required this.createdAt,
    required this.status,
  });

  factory DuelInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtRaw = data['createdAt'];
    DateTime createdDate = DateTime.now();
    if (createdAtRaw is Timestamp) {
      createdDate = createdAtRaw.toDate();
    }

    return DuelInvite(
      id: doc.id,
      fromUid: data['fromUid']?.toString() ?? '',
      fromUsername: data['fromUsername']?.toString() ?? 'Oyuncu',
      fromAvatar: data['fromAvatar']?.toString() ?? '1',
      roomCode: data['roomCode']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Genel Kültür',
      difficulty: data['difficulty']?.toString() ?? 'Orta',
      betTokens: (data['betTokens'] as num?)?.toInt() ?? 50,
      createdAt: createdDate,
      status: data['status']?.toString() ?? 'pending',
    );
  }
}

class PokeMessage {
  final String id;
  final String fromUid;
  final String fromUsername;
  final DateTime createdAt;

  PokeMessage({
    required this.id,
    required this.fromUid,
    required this.fromUsername,
    required this.createdAt,
  });

  factory PokeMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtRaw = data['createdAt'];
    DateTime createdDate = DateTime.now();
    if (createdAtRaw is Timestamp) {
      createdDate = createdAtRaw.toDate();
    }

    return PokeMessage(
      id: doc.id,
      fromUid: data['fromUid']?.toString() ?? '',
      fromUsername: data['fromUsername']?.toString() ?? 'Arkadaşın',
      createdAt: createdDate,
    );
  }
}

class DuelInviteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final Map<String, DateTime> _pokeCooldowns = {};

  /// 1v1 Düello Daveti Gönder
  static Future<bool> sendDuelInvite({
    required String toUid,
    required String roomCode,
    required DuelConfig config,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || myUid == toUid) return false;

    try {
      final userProfile = await UserService.getUserProfile(myUid);
      final myUsername = userProfile?['username']?.toString() ?? _auth.currentUser?.displayName ?? 'Oyuncu';
      final myAvatar = userProfile?['avatarIndex']?.toString() ?? '1';

      final inviteRef = _firestore
          .collection('users')
          .doc(toUid)
          .collection('duel_invites')
          .doc();

      await inviteRef.set({
        'fromUid': myUid,
        'fromUsername': myUsername,
        'fromAvatar': myAvatar,
        'roomCode': roomCode,
        'category': config.category,
        'difficulty': config.difficulty,
        'betTokens': config.betTokens,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Send duel invite error: $e');
      return false;
    }
  }

  /// Gelen Düello Davetlerini Canlı Dinle
  static Stream<List<DuelInvite>> streamIncomingInvites(String myUid) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('duel_invites')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => DuelInvite.fromDoc(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Daveti Yanıtla (Kabul veya Ret)
  static Future<void> respondToInvite({
    required String myUid,
    required String inviteId,
    required bool accept,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(myUid)
          .collection('duel_invites')
          .doc(inviteId)
          .update({
        'status': accept ? 'accepted' : 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Respond to invite error: $e');
    }
  }

  /// Arkadaşı Dürt (Poke / Nudge)
  static Future<Map<String, dynamic>> pokeFriend(String toUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || myUid == toUid) {
      return {'success': false, 'message': 'common.error'};
    }

    // 2 dakikalık soğuma süresi kontrolü
    final lastPoke = _pokeCooldowns[toUid];
    if (lastPoke != null && DateTime.now().difference(lastPoke).inSeconds < 120) {
      final remaining = 120 - DateTime.now().difference(lastPoke).inSeconds;
      return {
        'success': false,
        'message': 'friends.poke_cooldown',
        'remaining': remaining,
      };
    }

    try {
      final userProfile = await UserService.getUserProfile(myUid);
      final myUsername = userProfile?['username']?.toString() ?? _auth.currentUser?.displayName ?? 'Oyuncu';

      await _firestore
          .collection('users')
          .doc(toUid)
          .collection('pokes')
          .add({
        'fromUid': myUid,
        'fromUsername': myUsername,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _pokeCooldowns[toUid] = DateTime.now();
      return {'success': true, 'message': 'friends.poked_success'};
    } catch (e) {
      debugPrint('Poke error: $e');
      return {'success': false, 'message': 'common.error'};
    }
  }

  /// Gelen Dürtmeleri Canlı Dinle
  static Stream<List<PokeMessage>> streamIncomingPokes(String myUid) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('pokes')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => PokeMessage.fromDoc(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Dürtmeyi Temizle
  static Future<void> deletePoke(String myUid, String pokeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(myUid)
          .collection('pokes')
          .doc(pokeId)
          .delete();
    } catch (_) {}
  }
}
