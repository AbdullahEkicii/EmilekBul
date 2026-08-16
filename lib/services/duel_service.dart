import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/duel_room_model.dart';
import '../models/question.dart';

class DuelService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'duel_rooms';

  /// 6 Haneli Benzersiz Oda Kodu Üretir
  static String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Yeni Oda Oluştur
  static Future<String> createRoom({
    required DuelPlayer hostPlayer,
    DuelConfig? config,
  }) async {
    final roomConfig = config ?? const DuelConfig();
    String roomCode = generateRoomCode();

    // Kullanıcının daha önceden açık kalmış (askıda/orphaned) bekleyen odalarını otomatik kapat
    try {
      final existingRooms = await _firestore
          .collection(_collectionName)
          .where('hostUid', isEqualTo: hostPlayer.uid)
          .where('status', isEqualTo: 'waiting')
          .get();

      for (final existingDoc in existingRooms.docs) {
        await existingDoc.reference.update({
          'status': 'closed',
          'lastActivity': FieldValue.serverTimestamp(),
          'closeReason': 'replaced_by_new_room',
        });
      }
    } catch (e) {
      debugPrint('Error closing previous user rooms: $e');
    }

    // Kod çakışmasını engellemek için kontrol
    var doc = await _firestore.collection(_collectionName).doc(roomCode).get();
    int retries = 0;
    while (doc.exists && retries < 5) {
      roomCode = generateRoomCode();
      doc = await _firestore.collection(_collectionName).doc(roomCode).get();
      retries++;
    }

    final room = DuelRoom(
      roomCode: roomCode,
      hostUid: hostPlayer.uid,
      host: hostPlayer,
      guest: null,
      status: 'waiting',
      config: roomConfig,
      questions: const [],
      prizeTokens: DuelRoom.calculatePrize(roomConfig.betTokens),
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_collectionName).doc(roomCode).set(room.toMap());
    return roomCode;
  }

  /// Odaya Katılma İsteği Gönder
  static Future<Map<String, dynamic>> requestJoinRoom({
    required String roomCode,
    required DuelPlayer guestPlayer,
  }) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final docRef = _firestore.collection(_collectionName).doc(normalizedCode);
    final doc = await docRef.get();

    if (!doc.exists) {
      return {'success': false, 'message': 'duel.room_not_found'};
    }

    final data = doc.data()!;
    final status = data['status'] as String? ?? 'waiting';

    if (status == 'closed') {
      return {'success': false, 'message': 'duel.room_closed'};
    }

    // Eğer kullanıcı zaten oda sahibiyse
    if (data['hostUid'] == guestPlayer.uid) {
      return {'success': true, 'roomCode': normalizedCode, 'isHost': true, 'isDirect': true};
    }

    // Eğer kullanıcı zaten onaylı misafirse
    if (data['guest'] != null && data['guest']['uid'] == guestPlayer.uid) {
      return {'success': true, 'roomCode': normalizedCode, 'isHost': false, 'isDirect': true};
    }

    // Eğer oda doluysa
    if (data['guest'] != null) {
      return {'success': false, 'message': 'duel.room_full'};
    }

    final isHostBot = data['hostUid']?.toString().startsWith('bot_') == true;

    // Eğer oda sahibi bir botsa, beklemeden ANINDA odaya misafir olarak dahil et
    if (isHostBot) {
      await docRef.update({
        'guest': guestPlayer.toMap(),
        'pendingGuest': null,
        'joinRequestStatus': 'approved',
        'lastActivity': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'roomCode': normalizedCode, 'isHost': false, 'isDirect': true};
    }

    // Gerçek kullanıcı odası için onay isteği yaz
    await docRef.update({
      'pendingGuest': guestPlayer.toMap(),
      'joinRequestStatus': 'pending',
      'lastActivity': FieldValue.serverTimestamp(),
    });

    return {'success': true, 'roomCode': normalizedCode, 'isHost': false, 'isPending': true};
  }

  /// Katılma İsteğini Onayla (Oda Sahibi)
  static Future<void> approveJoinRequest(String roomCode) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final docRef = _firestore.collection(_collectionName).doc(normalizedCode);
    final doc = await docRef.get();

    if (!doc.exists) return;
    final data = doc.data()!;
    final pendingGuest = data['pendingGuest'];

    if (pendingGuest != null) {
      await docRef.update({
        'guest': pendingGuest,
        'pendingGuest': null,
        'joinRequestStatus': 'approved',
        'status': 'ready',
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Katılma İsteğini Reddet (Oda Sahibi)
  static Future<void> rejectJoinRequest(String roomCode) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    await _firestore.collection(_collectionName).doc(normalizedCode).update({
      'pendingGuest': null,
      'joinRequestStatus': 'rejected',
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Katılma İsteğini İptal Et (Misafir Oyuncu)
  static Future<void> cancelJoinRequest(String roomCode, String guestUid) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final docRef = _firestore.collection(_collectionName).doc(normalizedCode);
    final doc = await docRef.get();
    if (doc.exists && doc.data()?['pendingGuest']?['uid'] == guestUid) {
      await docRef.update({
        'pendingGuest': null,
        'joinRequestStatus': 'none',
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Odaya Doğrudan Katıl (Eski uyumluluk)
  static Future<Map<String, dynamic>> joinRoom({
    required String roomCode,
    required DuelPlayer guestPlayer,
  }) async {
    return requestJoinRoom(roomCode: roomCode, guestPlayer: guestPlayer);
  }

  /// Odayı Gerçek Zamanlı Dinle (Stream)
  static Stream<DuelRoom?> streamRoom(String roomCode) {
    final normalizedCode = roomCode.trim().toUpperCase();
    return _firestore
        .collection(_collectionName)
        .doc(normalizedCode)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return DuelRoom.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  /// Açık Bekleyen Odaları Canlı Dinle (Stream) & Bayat Odaları Otomatik Temizle
  static Stream<List<DuelRoom>> streamOpenRooms() {
    return _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final List<DuelRoom> validRooms = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final room = DuelRoom.fromMap(data, doc.id);
        final createdAt = room.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        DateTime lastActive = createdAt;
        final lastActivityRaw = data['lastActivity'];
        if (lastActivityRaw is Timestamp) {
          lastActive = lastActivityRaw.toDate();
        }

        // 2 dakikadan uzun süredir aktivite olmayan veya 3.5 dakikadan eski terk edilmiş odaları kapat
        final isOld = now.difference(lastActive).inSeconds >= 120 || now.difference(createdAt).inMinutes >= 4;

        if (isOld) {
          // Arka planda odayı kapat
          _firestore.collection(_collectionName).doc(doc.id).update({
            'status': 'closed',
            'lastActivity': FieldValue.serverTimestamp(),
            'closeReason': 'stale_timeout',
          }).catchError((_) {});
        } else {
          validRooms.add(room);
        }
      }

      // En son oluşturulanlar üstte
      validRooms.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return validRooms;
    });
  }

  /// Oda Canlılık Sinyali (Heartbeat / Ping)
  static Future<void> pingRoom(String roomCode) async {
    try {
      final normalizedCode = roomCode.trim().toUpperCase();
      await _firestore.collection(_collectionName).doc(normalizedCode).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Oda Ayarlarını Güncelle (Oda Sahibi)
  static Future<void> updateRoomConfig(String roomCode, DuelConfig newConfig) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    await _firestore.collection(_collectionName).doc(normalizedCode).update({
      'config': newConfig.toMap(),
      'prizeTokens': DuelRoom.calculatePrize(newConfig.betTokens),
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Oda Durumunu Güncelle (örn: 'starting', 'ready', 'waiting')
  static Future<void> setRoomStatus(String roomCode, String status) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    await _firestore.collection(_collectionName).doc(normalizedCode).update({
      'status': status,
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Oyuncu Hazır Durumunu Güncelle (Host veya Guest)
  static Future<void> setPlayerReady(String roomCode, {required bool isHost, required bool isReady}) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final field = isHost ? 'host.isReady' : 'guest.isReady';
    await _firestore.collection(_collectionName).doc(normalizedCode).update({
      field: isReady,
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Oda Sahibi Başlatma Niyetini Güncelle
  static Future<void> setHostWantsToStart(String roomCode, {required bool wantsToStart}) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    await _firestore.collection(_collectionName).doc(normalizedCode).update({
      'hostWantsToStart': wantsToStart,
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Oyuncu Bakiye / Profil Verilerini Senkronize Et
  static Future<void> syncPlayerProfile(String roomCode, {required bool isHost, required DuelPlayer player}) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final field = isHost ? 'host' : 'guest';
    await _firestore.collection(_collectionName).doc(normalizedCode).update({
      '$field.username': player.username,
      '$field.avatarIndex': player.avatarIndex,
      '$field.equippedFrame': player.equippedFrame,
      '$field.equippedTitle': player.equippedTitle,
      '$field.tokens': player.tokens,
      '$field.language': player.language,
    });
  }

  /// Yarışı Başlat (Host)
  static Future<void> startDuel({
    required String roomCode,
    required List<Question> questions,
    required int betTokens,
  }) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final prize = DuelRoom.calculatePrize(betTokens);

    await _firestore.collection(_collectionName).doc(normalizedCode).update({
      'questions': questions.map((q) => q.toJson()).toList(),
      'status': 'in_game',
      'prizeTokens': prize,
      'winnerUid': null,
      'host.progress': 0,
      'host.score': 0,
      'host.finished': false,
      'host.finishTime': 0,
      'host.userAnswers': [],
      'guest.progress': 0,
      'guest.score': 0,
      'guest.finished': false,
      'guest.finishTime': 0,
      'guest.userAnswers': [],
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Oyuncu İlerlemesini ve Skorunu Güncelle
  static Future<void> updatePlayerProgress({
    required String roomCode,
    required bool isHost,
    required int progress,
    required int score,
    bool finished = false,
    int finishTime = 0,
    List<int?>? userAnswers,
  }) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final field = isHost ? 'host' : 'guest';

    final Map<String, dynamic> updates = {
      '$field.progress': progress,
      '$field.score': score,
      '$field.finished': finished,
    };

    if (finished) {
      updates['$field.finishTime'] = finishTime;
    }
    if (userAnswers != null) {
      updates['$field.userAnswers'] = userAnswers;
    }

    await _firestore.collection(_collectionName).doc(normalizedCode).update(updates);
  }

  /// Test Bitiminde Kazananı Belirle, Ödülü Dağıt ve Firebase'e Detaylı Log Kaydet
  static Future<void> resolveDuelResult(String roomCode) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final docRef = _firestore.collection(_collectionName).doc(normalizedCode);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) return;

        final data = snapshot.data()!;
        if (data['status'] == 'finished') return; // Zaten sonuçlandırılmış

        final hostData = (data['host'] is Map) ? (data['host'] as Map) : {};
        final guestData = (data['guest'] is Map) ? (data['guest'] as Map) : {};

        final int hostScore = (hostData['score'] as num?)?.toInt() ?? 0;
        final int guestScore = (guestData['score'] as num?)?.toInt() ?? 0;
        final int hostTime = (hostData['finishTime'] as num?)?.toInt() ?? 999999;
        final int guestTime = (guestData['finishTime'] as num?)?.toInt() ?? 999999;

        String? winnerUid;
        if (hostScore > guestScore) {
          winnerUid = hostData['uid']?.toString();
        } else if (guestScore > hostScore) {
          winnerUid = guestData['uid']?.toString();
        } else {
          // Eşitlik durumunda süreye bakılır
          if (hostTime < guestTime) {
            winnerUid = hostData['uid'] as String?;
          } else if (guestTime < hostTime) {
            winnerUid = guestData['uid'] as String?;
          } else {
            winnerUid = 'tie'; // Tam beraberlik
          }
        }

        // 1. Oda durumunu güncelle
        transaction.update(docRef, {
          'status': 'finished',
          'winnerUid': winnerUid,
          'lastActivity': FieldValue.serverTimestamp(),
        });

        // 2. Firebase Takip için 'duel_match_logs' koleksiyonuna detaylı kayıt oluştur
        final logDocRef = _firestore.collection('duel_match_logs').doc();
        final configData = (data['config'] is Map) ? (data['config'] as Map) : {};

        final matchLogData = {
          'matchId': logDocRef.id,
          'roomCode': normalizedCode,
          'category': configData['category']?.toString() ?? 'Genel Kültür',
          'difficulty': configData['difficulty']?.toString() ?? 'Orta',
          'questionCount': (configData['questionCount'] as num?)?.toInt() ?? 5,
          'betTokens': (configData['betTokens'] as num?)?.toInt() ?? 50,
          'prizeTokens': (data['prizeTokens'] as num?)?.toInt() ?? 0,
          'winnerUid': winnerUid,
          'isTie': winnerUid == 'tie',
          'host': {
            'uid': hostData['uid']?.toString() ?? '',
            'username': hostData['username']?.toString() ?? 'Oyuncu 1',
            'avatarIndex': hostData['avatarIndex']?.toString() ?? '1',
            'equippedFrame': hostData['equippedFrame']?.toString() ?? '0',
            'equippedTitle': hostData['equippedTitle']?.toString() ?? 'yok',
            'score': hostScore,
            'finishTime': hostTime,
            'language': hostData['language']?.toString() ?? 'tr',
            'userAnswers': hostData['userAnswers'],
          },
          'guest': {
            'uid': guestData['uid']?.toString() ?? '',
            'username': guestData['username']?.toString() ?? 'Oyuncu 2',
            'avatarIndex': guestData['avatarIndex']?.toString() ?? '1',
            'equippedFrame': guestData['equippedFrame']?.toString() ?? '0',
            'equippedTitle': guestData['equippedTitle']?.toString() ?? 'yok',
            'score': guestScore,
            'finishTime': guestTime,
            'language': guestData['language']?.toString() ?? 'tr',
            'userAnswers': guestData['userAnswers'],
          },
          'languages': {
            'host': hostData['language']?.toString() ?? 'tr',
            'guest': guestData['language']?.toString() ?? 'tr',
          },
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
        };

        transaction.set(logDocRef, matchLogData);
      });
    } catch (e) {
      debugPrint('Error resolving duel result: $e');
    }
  }

  /// Lobiye Dönüş / Tekrar Oyna (Rematch & Return to Lobby)
  static Future<void> returnToLobby(String roomCode, {required bool isHost}) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final docRef = _firestore.collection(_collectionName).doc(normalizedCode);

    try {
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final currentStatus = data['status']?.toString();

      if (currentStatus == 'finished' || currentStatus == 'in_game') {
        final guestData = data['guest'];
        await docRef.update({
          'status': guestData != null ? 'ready' : 'waiting',
          'questions': [],
          'winnerUid': null,
          'host.progress': 0,
          'host.score': 0,
          'host.finished': false,
          'host.finishTime': 0,
          'host.userAnswers': [],
          if (guestData != null) ...{
            'guest.progress': 0,
            'guest.score': 0,
            'guest.finished': false,
            'guest.finishTime': 0,
            'guest.userAnswers': [],
          },
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error returning to lobby: $e');
    }
  }

  /// Odadan Ayrıl
  static Future<void> leaveRoom(String roomCode, {required bool isHost, required String uid}) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    final docRef = _firestore.collection(_collectionName).doc(normalizedCode);

    try {
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;

      final hostUid = data['hostUid']?.toString();
      final guestData = (data['guest'] is Map) ? (data['guest'] as Map) : null;
      final guestUid = guestData?['uid']?.toString();

      final bool isHostBot = hostUid?.startsWith('bot_') == true;

      if (isHostBot) {
        // Misafir bot odasından ayrıldı: Bot odasını doğrudan kapat
        await docRef.update({
          'status': 'closed',
          'lastActivity': FieldValue.serverTimestamp(),
        });
        return;
      }

      final bool actuallyHost = isHost || (hostUid == uid);

      if (actuallyHost) {
        if (guestData != null && guestUid != null && guestUid != uid) {
          // Oda sahibi ayrıldı, misafir odada: Misafiri yeni oda sahibi yap!
          await docRef.update({
            'hostUid': guestUid,
            'host': guestData,
            'guest': null,
            'status': 'waiting',
            'questions': [],
            'winnerUid': null,
            'host.progress': 0,
            'host.score': 0,
            'host.finished': false,
            'host.finishTime': 0,
            'host.userAnswers': [],
            'lastActivity': FieldValue.serverTimestamp(),
          });
        } else {
          // Odada başka oyuncu yoksa odayı kapat
          await docRef.update({
            'status': 'closed',
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Misafir ayrıldı
        await docRef.update({
          'guest': null,
          'status': 'waiting',
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  /// Odaya Mesaj / Emoji Gönder
  static Future<void> sendRoomMessage(String roomCode, DuelChatMessage message) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    try {
      await _firestore
          .collection(_collectionName)
          .doc(normalizedCode)
          .collection('messages')
          .add(message.toMap());
    } catch (e) {
      debugPrint('Error sending room message: $e');
    }
  }

  /// Oda Mesajlarını Canlı Dinle
  static Stream<List<DuelChatMessage>> streamRoomMessages(String roomCode) {
    final normalizedCode = roomCode.trim().toUpperCase();
    return _firestore
        .collection(_collectionName)
        .doc(normalizedCode)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => DuelChatMessage.fromDoc(doc)).toList();
      list.sort((a, b) {
        final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tA.compareTo(tB);
      });
      if (list.length > 50) {
        return list.sublist(list.length - 50);
      }
      return list;
    });
  }
}
