import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

class PresenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _usersCollection = 'users';

  static Timer? _heartbeatTimer;

  /// Çevrimiçi Varlık Takibini Başlat
  static void startPresence() {
    _heartbeatTimer?.cancel();
    updatePresence(true);

    // Her 60 saniyede bir son görülme zaman damgasını tazele
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      updatePresence(true);
    });
  }

  /// Çevrimiçi Durumunu Güncelle
  static Future<void> updatePresence(bool isOnline) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection(_usersCollection).doc(uid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Update presence error: $e');
    }
  }

  /// Uygulama kapandığında veya arka plana geçtiğinde
  static void stopPresence() {
    _heartbeatTimer?.cancel();
    updatePresence(false);
  }

  /// Bir kullanıcının anlık çevrimiçi durumunu dinle
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamPresence(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots();
  }

  /// Son Görülme Metnini Formatla
  static String formatLastSeen({required DateTime? lastSeen, required bool isOnline}) {
    if (lastSeen == null) {
      return isOnline ? 'friends.online'.tr() : 'friends.offline'.tr();
    }

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    // Son 3 dakika içindeyse ve isOnline true ise kesinlikle çevrimiçi
    if (difference.inMinutes < 3 && isOnline) {
      return 'friends.online'.tr();
    }

    if (difference.inMinutes < 1) {
      return 'friends.just_now'.tr();
    } else if (difference.inMinutes < 60) {
      return 'friends.minutes_ago'.tr(args: [difference.inMinutes.toString()]);
    } else if (difference.inHours < 24) {
      return 'friends.hours_ago'.tr(args: [difference.inHours.toString()]);
    } else if (difference.inDays < 7) {
      return 'friends.days_ago'.tr(args: [difference.inDays.toString()]);
    } else {
      return DateFormat('dd.MM.yyyy').format(lastSeen);
    }
  }

  /// Gerçekten Çevrimiçi mi? (Son 3 dakika kontrolü)
  static bool isUserOnline({required DateTime? lastSeen, required bool isOnline}) {
    if (lastSeen == null) return isOnline;
    final difference = DateTime.now().difference(lastSeen);
    return isOnline && difference.inMinutes < 4;
  }
}
