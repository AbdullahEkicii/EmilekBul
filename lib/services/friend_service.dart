import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_model.dart';
import 'user_service.dart';

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String friendsSubcollection = 'friends';
  static const String requestsCollection = 'friend_requests';
  static const String usersCollection = 'users';

  /// Arkadaşlık isteği gönder
  static Future<Map<String, dynamic>> sendFriendRequest(String toUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'message': 'auth.not_logged_in'};
    }
    if (currentUser.uid == toUid) {
      return {'success': false, 'message': 'friends.cannot_add_self'};
    }

    try {
      // 1. Zaten arkadaş mı kontrol et
      final friendDoc = await _firestore
          .collection(usersCollection)
          .doc(currentUser.uid)
          .collection(friendsSubcollection)
          .doc(toUid)
          .get();
      if (friendDoc.exists) {
        return {'success': false, 'message': 'friends.already_friends'};
      }

      // 2. Karşı taraftan bize gelen bekleyen istek var mı?
      final incomingReqDoc = await _firestore
          .collection(requestsCollection)
          .doc('${toUid}_${currentUser.uid}')
          .get();
      if (incomingReqDoc.exists && incomingReqDoc.data()?['status'] == 'pending') {
        // Otomatik kabul et
        final req = FriendRequest.fromDoc(incomingReqDoc);
        return await acceptFriendRequest(req);
      }

      // 3. Zaten istek atılmış mı kontrol et
      final requestId = '${currentUser.uid}_$toUid';
      final existingReqDoc = await _firestore.collection(requestsCollection).doc(requestId).get();
      if (existingReqDoc.exists && existingReqDoc.data()?['status'] == 'pending') {
        return {'success': false, 'message': 'friends.request_already_sent'};
      }

      // 4. Profil bilgilerini çek
      final senderProfile = await UserService.getUserProfile(currentUser.uid);
      final receiverProfile = await UserService.getUserProfile(toUid);

      final senderName = senderProfile?['username'] ?? 'Oyuncu';
      final senderAvatar = senderProfile?['avatarIndex'] ?? '0';
      final senderFrame = senderProfile?['equippedFrame'] ?? '0';
      final senderTitle = senderProfile?['equippedTitle'] ?? 'yok';

      final receiverName = receiverProfile?['username'] ?? 'Oyuncu';
      final receiverAvatar = receiverProfile?['avatarIndex'] ?? '0';
      final receiverFrame = receiverProfile?['equippedFrame'] ?? '0';
      final receiverTitle = receiverProfile?['equippedTitle'] ?? 'yok';

      final request = FriendRequest(
        id: requestId,
        fromUid: currentUser.uid,
        toUid: toUid,
        fromUsername: senderName,
        fromAvatarIndex: senderAvatar,
        fromEquippedFrame: senderFrame,
        fromEquippedTitle: senderTitle,
        toUsername: receiverName,
        toAvatarIndex: receiverAvatar,
        toEquippedFrame: receiverFrame,
        toEquippedTitle: receiverTitle,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestore.collection(requestsCollection).doc(requestId).set(request.toMap());

      return {'success': true, 'message': 'friends.request_sent_success'};
    } catch (e) {
      debugPrint('Send friend request error: $e');
      return {'success': false, 'message': 'common.error'};
    }
  }

  /// Arkadaşlık isteğini kabul et
  static Future<Map<String, dynamic>> acceptFriendRequest(FriendRequest request) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'message': 'auth.not_logged_in'};
    }

    try {
      // Profil verilerini al
      final userAProfile = await UserService.getUserProfile(request.fromUid);
      final userBProfile = await UserService.getUserProfile(request.toUid);

      final userA = FriendUser(
        uid: request.fromUid,
        username: userAProfile?['username'] ?? request.fromUsername,
        avatarIndex: userAProfile?['avatarIndex'] ?? request.fromAvatarIndex,
        equippedFrame: userAProfile?['equippedFrame'] ?? request.fromEquippedFrame,
        equippedTitle: userAProfile?['equippedTitle'] ?? request.fromEquippedTitle,
        level: (userAProfile?['level'] as num?)?.toInt() ?? 1,
        totalPoints: (userAProfile?['totalPoints'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.now(),
      );

      final userB = FriendUser(
        uid: request.toUid,
        username: userBProfile?['username'] ?? request.toUsername,
        avatarIndex: userBProfile?['avatarIndex'] ?? request.toAvatarIndex,
        equippedFrame: userBProfile?['equippedFrame'] ?? request.toEquippedFrame,
        equippedTitle: userBProfile?['equippedTitle'] ?? request.toEquippedTitle,
        level: (userBProfile?['level'] as num?)?.toInt() ?? 1,
        totalPoints: (userBProfile?['totalPoints'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.now(),
      );

      final batch = _firestore.batch();

      // userA'nın arkadaşlarına userB'yi ekle
      final refA = _firestore
          .collection(usersCollection)
          .doc(request.fromUid)
          .collection(friendsSubcollection)
          .doc(request.toUid);
      batch.set(refA, userB.toMap());

      // userB'nin arkadaşlarına userA'yı ekle
      final refB = _firestore
          .collection(usersCollection)
          .doc(request.toUid)
          .collection(friendsSubcollection)
          .doc(request.fromUid);
      batch.set(refB, userA.toMap());

      // İstek dökümanlarını sil (her iki yöndeki olası istekler temizlensin)
      final reqRef1 = _firestore.collection(requestsCollection).doc(request.id);
      batch.delete(reqRef1);
      final reqRef2 = _firestore.collection(requestsCollection).doc('${request.fromUid}_${request.toUid}');
      batch.delete(reqRef2);
      final reqRef3 = _firestore.collection(requestsCollection).doc('${request.toUid}_${request.fromUid}');
      batch.delete(reqRef3);

      // Profil friendsCount ve friendly başarımını güncelle
      final refAUser = _firestore.collection(usersCollection).doc(request.fromUid);
      final refBUser = _firestore.collection(usersCollection).doc(request.toUid);
      batch.update(refAUser, {
        'friendsCount': FieldValue.increment(1),
        'unlockedBadges': FieldValue.arrayUnion(['friendly']),
      });
      batch.update(refBUser, {
        'friendsCount': FieldValue.increment(1),
        'unlockedBadges': FieldValue.arrayUnion(['friendly']),
      });

      await batch.commit();

      return {'success': true, 'message': 'friends.request_accepted'};
    } catch (e) {
      debugPrint('Accept friend request error: $e');
      return {'success': false, 'message': 'common.error'};
    }
  }

  /// Arkadaşlık isteğini reddet / sil
  static Future<bool> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection(requestsCollection).doc(requestId).delete();
      return true;
    } catch (e) {
      debugPrint('Reject friend request error: $e');
      return false;
    }
  }

  /// Gönderilen isteği iptal et
  static Future<bool> cancelFriendRequest(String toUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return false;
    try {
      final requestId = '${myUid}_$toUid';
      await _firestore.collection(requestsCollection).doc(requestId).delete();
      return true;
    } catch (e) {
      debugPrint('Cancel friend request error: $e');
      return false;
    }
  }

  /// Arkadaşlıktan çıkar
  static Future<bool> removeFriend(String friendUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return false;

    try {
      final batch = _firestore.batch();

      final ref1 = _firestore
          .collection(usersCollection)
          .doc(myUid)
          .collection(friendsSubcollection)
          .doc(friendUid);
      batch.delete(ref1);

      final ref2 = _firestore
          .collection(usersCollection)
          .doc(friendUid)
          .collection(friendsSubcollection)
          .doc(myUid);
      batch.delete(ref2);

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Remove friend error: $e');
      return false;
    }
  }

  /// Kullanıcının arkadaşlarını anlık dinle
  static Stream<List<FriendUser>> streamFriends(String uid) {
    return _firestore
        .collection(usersCollection)
        .doc(uid)
        .collection(friendsSubcollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FriendUser.fromDoc(doc)).toList();
    });
  }

  /// Kullanıcıya gelen bekleyen arkadaşlık isteklerini dinle
  static Stream<List<FriendRequest>> streamIncomingRequests(String uid) {
    return _firestore
        .collection(requestsCollection)
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FriendRequest.fromDoc(doc)).toList();
    });
  }

  /// Gelen bekleyen istek sayısını dinle
  static Stream<int> streamIncomingRequestsCount(String uid) {
    return _firestore
        .collection(requestsCollection)
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// İki kullanıcı arasındaki arkadaşlık durumunu anlık kontrol et
  static Future<FriendshipStatus> checkFriendshipStatus(String otherUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || myUid == otherUid) return FriendshipStatus.none;

    try {
      // 1. Arkadaş mı?
      final friendDoc = await _firestore
          .collection(usersCollection)
          .doc(myUid)
          .collection(friendsSubcollection)
          .doc(otherUid)
          .get();
      if (friendDoc.exists) return FriendshipStatus.friends;

      // 2. Ben istek gönderdim mi?
      final sentReq = await _firestore
          .collection(requestsCollection)
          .doc('${myUid}_$otherUid')
          .get();
      if (sentReq.exists && sentReq.data()?['status'] == 'pending') {
        return FriendshipStatus.sentPending;
      }

      // 3. Karşı taraf bana istek gönderdi mi?
      final receivedReq = await _firestore
          .collection(requestsCollection)
          .doc('${otherUid}_$myUid')
          .get();
      if (receivedReq.exists && receivedReq.data()?['status'] == 'pending') {
        return FriendshipStatus.receivedPending;
      }

      return FriendshipStatus.none;
    } catch (e) {
      debugPrint('Check friendship status error: $e');
      return FriendshipStatus.none;
    }
  }

  /// İki kullanıcı arasındaki arkadaşlık durumunu anlık (real-time stream) dinle
  static Stream<FriendshipStatus> streamFriendshipStatus(String otherUid) {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || myUid.isEmpty || otherUid.isEmpty || myUid == otherUid) {
      return Stream.value(FriendshipStatus.none);
    }

    final friendsStream = _firestore
        .collection(usersCollection)
        .doc(myUid)
        .collection(friendsSubcollection)
        .doc(otherUid)
        .snapshots();

    final sentStream = _firestore
        .collection(requestsCollection)
        .doc('${myUid}_$otherUid')
        .snapshots();

    final receivedStream = _firestore
        .collection(requestsCollection)
        .doc('${otherUid}_$myUid')
        .snapshots();

    late StreamController<FriendshipStatus> controller;
    StreamSubscription? sub1;
    StreamSubscription? sub2;
    StreamSubscription? sub3;

    void updateStatus() async {
      final status = await checkFriendshipStatus(otherUid);
      if (!controller.isClosed) {
        controller.add(status);
      }
    }

    controller = StreamController<FriendshipStatus>(
      onListen: () {
        sub1 = friendsStream.listen((_) => updateStatus());
        sub2 = sentStream.listen((_) => updateStatus());
        sub3 = receivedStream.listen((_) => updateStatus());
        updateStatus();
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
        sub3?.cancel();
      },
    );

    return controller.stream;
  }

  /// Belirli bir kullanıcıdan gelen bekleyen arkadaşlık isteğini kabul et
  static Future<Map<String, dynamic>> acceptRequestFrom(String fromUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return {'success': false, 'message': 'auth.not_logged_in'};

    final reqDoc = await _firestore.collection(requestsCollection).doc('${fromUid}_$myUid').get();
    if (reqDoc.exists) {
      final req = FriendRequest.fromDoc(reqDoc);
      return await acceptFriendRequest(req);
    } else {
      return await sendFriendRequest(fromUid);
    }
  }

  /// İsme göre kullanıcı ara (Çok dilli Misafir / Guest araması destekli)
  /// İsme göre kullanıcı ara (Çok dilli Misafir / Guest ve Büyük/Küçük harf uyumlu)
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final rawQuery = query.trim();
    final cleanQuery = rawQuery.toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final myUid = _auth.currentUser?.uid;
    final Set<String> foundUids = {};
    final List<Map<String, dynamic>> results = [];

    // Olası arama varyasyonları
    final List<String> lowerSearchTerms = [cleanQuery];
    final String capitalized = rawQuery.isNotEmpty
        ? (rawQuery[0].toUpperCase() + (rawQuery.length > 1 ? rawQuery.substring(1) : ''))
        : '';
    final List<String> rawSearchTerms = [rawQuery, capitalized, cleanQuery]
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    // Çok dilli misafir kelimeleri listesi
    final guestPrefixes = [
      'misafir', 'guest', 'gast', 'invitado', 'invité', 'ospite',
      'гость', 'gäste', 'convidado', 'gość', 'vendeeg', 'keluarga'
    ];

    for (final prefix in guestPrefixes) {
      if (cleanQuery.startsWith(prefix)) {
        var remainder = cleanQuery.substring(prefix.length).trim();
        if (remainder.startsWith('_')) remainder = remainder.substring(1).trim();

        if (remainder.isNotEmpty) {
          lowerSearchTerms.add('misafir$remainder');
          lowerSearchTerms.add('misafir $remainder');
          lowerSearchTerms.add('misafir_$remainder');
        } else {
          lowerSearchTerms.add('misafir');
        }
        break;
      }
    }

    void processDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      if (doc.id == myUid || foundUids.contains(doc.id)) return;
      foundUids.add(doc.id);
      final data = doc.data() ?? {};

      // Eğer kullanıcının username_lower alanı eksikse arka planda otomatik ekle
      if (data['username_lower'] == null && data['username'] != null) {
        final uName = data['username'].toString().trim();
        if (uName.isNotEmpty) {
          doc.reference.update({'username_lower': uName.toLowerCase()}).catchError((_) {});
        }
      }

      results.add({
        'uid': doc.id,
        'username': data['username'] ?? 'Oyuncu',
        'avatarIndex': data['avatarIndex'] ?? '0',
        'equippedFrame': data['equippedFrame'] ?? '0',
        'equippedTitle': data['equippedTitle'] ?? 'yok',
        'level': (data['level'] as num?)?.toInt() ?? 1,
        'totalPoints': (data['totalPoints'] as num?)?.toInt() ?? 0,
        'isGuest': data['isGuest'] == true,
      });
    }

    try {
      // 1. username_lower üzerinden arama
      for (final term in lowerSearchTerms.toSet()) {
        final querySnapshot = await _firestore
            .collection(usersCollection)
            .where('username_lower', isGreaterThanOrEqualTo: term)
            .where('username_lower', isLessThanOrEqualTo: '$term\uf8ff')
            .limit(15)
            .get();

        for (final doc in querySnapshot.docs) {
          processDoc(doc);
        }
      }

      // 2. username_lower alanı henüz olmayan eski hesaplar için orijinal 'username' üzerinden arama
      for (final term in rawSearchTerms) {
        final querySnapshot = await _firestore
            .collection(usersCollection)
            .where('username', isGreaterThanOrEqualTo: term)
            .where('username', isLessThanOrEqualTo: '$term\uf8ff')
            .limit(15)
            .get();

        for (final doc in querySnapshot.docs) {
          processDoc(doc);
        }
      }

      // 3. Birebir eşitlik araması (Büyük/küçük harf doğrudan eşleşme garantisi)
      for (final term in rawSearchTerms) {
        final exactSnapshot = await _firestore
            .collection(usersCollection)
            .where('username', isEqualTo: term)
            .limit(5)
            .get();

        for (final doc in exactSnapshot.docs) {
          processDoc(doc);
        }
      }
    } catch (e) {
      debugPrint('User search error: $e');
    }

    return results;
  }
}
