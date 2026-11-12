import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/friend_model.dart';
import 'user_service.dart';

/// Bir turnuvadaki tek bir katılımcının kaydı (`tournaments/{id}.participants.{uid}`).
class TournamentParticipant {
  final String uid;
  final String username;
  final int score; // Turnuvadaki en iyi tur skoru (doğru cevap sayısı)
  final int plays; // Oynanan tur sayısı

  const TournamentParticipant({
    required this.uid,
    required this.username,
    required this.score,
    required this.plays,
  });

  factory TournamentParticipant.fromMap(String uid, Map<dynamic, dynamic> map) {
    return TournamentParticipant(
      uid: uid,
      username: (map['username'] as String?) ?? 'Oyuncu',
      score: (map['score'] as num?)?.toInt() ?? 0,
      plays: (map['plays'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `tournaments/{id}` dokümanının istemci tarafı görünümü.
class Tournament {
  final String id;
  final String ownerUid;
  final String title;
  final String category; // CategoryItem.name
  final String status; // 'open' | 'finished'
  final Map<String, TournamentParticipant> participants;
  final DateTime? createdAt;
  final DateTime? endsAt;

  const Tournament({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.category,
    required this.status,
    required this.participants,
    this.createdAt,
    this.endsAt,
  });

  bool get isOpen =>
      status == 'open' && (endsAt == null || DateTime.now().isBefore(endsAt!));

  /// Skora göre sıralı katılımcılar (yüksek skor üstte).
  List<TournamentParticipant> get ranking {
    final list = participants.values.toList();
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  factory Tournament.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawParticipants = (data['participants'] as Map?) ?? {};
    final participants = <String, TournamentParticipant>{};
    rawParticipants.forEach((key, value) {
      if (key is String && value is Map) {
        participants[key] = TournamentParticipant.fromMap(key, value);
      }
    });
    return Tournament(
      id: doc.id,
      ownerUid: (data['ownerUid'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'open',
      participants: participants,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      endsAt: (data['endsAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Arkadaş turnuvası.
///
/// Davet modeli: turnuva oluşturulurken seçilen arkadaşlar doğrudan `participants`
/// haritasına eklenir (bekleyen davet durumu yok). Her katılımcı için
/// `users/{uid}/tournaments/{id}` indeks dokümanı da yazılır; böylece arkadaş
/// kendi listesinde turnuvayı görür. Katılımcı yalnızca kendi `participants.{uid}`
/// girdisini (skor/oynama sayısı) güncelleyebilir; bkz. firestore.rules.
class TournamentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String tournamentsCollection = 'tournaments';
  static const String usersCollection = 'users';
  static const String userIndexSubcollection = 'tournaments';

  /// Davet edilecek arkadaş sayısı (sahip hariç) ve toplam katılımcı sınırı.
  static const int minInvitees = 2;
  static const int maxInvitees = 7;
  static const int maxParticipants = 8;
  static const Duration duration = Duration(hours: 48);

  static CollectionReference<Map<String, dynamic>> get _tournaments =>
      _firestore.collection(tournamentsCollection);

  static CollectionReference<Map<String, dynamic>> _userIndex(String uid) => _firestore
      .collection(usersCollection)
      .doc(uid)
      .collection(userIndexSubcollection);

  /// Sahip olarak turnuva oluşturur ve seçilen arkadaşları davet eder.
  /// Dönüş: {'success': bool, 'message': i18n anahtarı, 'id': turnuva id (başarılıysa)}.
  static Future<Map<String, dynamic>> create({
    required String title,
    required String categoryName,
    required List<FriendUser> friends,
  }) async {
    final me = _auth.currentUser;
    if (me == null) return {'success': false, 'message': 'auth.not_logged_in'};

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 40) {
      return {'success': false, 'message': 'tournament.title_invalid'};
    }

    // Aynı arkadaş iki kez eklenmesin, kendimizi davet etmeyelim
    final inviteeUids = <String>{};
    for (final f in friends) {
      if (f.uid != me.uid) inviteeUids.add(f.uid);
    }
    if (inviteeUids.length < minInvitees || inviteeUids.length > maxInvitees) {
      return {'success': false, 'message': 'tournament.friend_count_invalid'};
    }

    try {
      final ownerProfile = await UserService.getUserProfile(me.uid);
      final ownerName = (ownerProfile?['username'] as String?) ?? 'Oyuncu';

      final now = DateTime.now();
      final endsAt = now.add(duration);
      final participants = <String, dynamic>{
        me.uid: {'username': ownerName, 'score': 0, 'plays': 0},
      };
      for (final f in friends) {
        if (!inviteeUids.contains(f.uid)) continue;
        participants[f.uid] = {'username': f.username, 'score': 0, 'plays': 0};
      }

      final ref = _tournaments.doc();
      await ref.set({
        'ownerUid': me.uid,
        'title': cleanTitle,
        'category': categoryName,
        'status': 'open',
        'participants': participants,
        'createdAt': Timestamp.fromDate(now),
        'endsAt': Timestamp.fromDate(endsAt),
      });

      // İndeks yazımı turnuva dokümanının varlığına bağlıdır (kurallardaki get() kontrolü),
      // bu yüzden ayrı bir batch olarak yazılır. Hata olursa turnuva geri alınır.
      try {
        final batch = _firestore.batch();
        for (final uid in participants.keys) {
          batch.set(_userIndex(uid).doc(ref.id), {
            'tournamentId': ref.id,
            'addedAt': Timestamp.fromDate(now),
          });
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Tournament index write error: $e');
        await ref.delete().catchError((_) {});
        return {'success': false, 'message': 'common.error'};
      }

      return {'success': true, 'message': 'tournament.created', 'id': ref.id};
    } catch (e) {
      debugPrint('Tournament create error: $e');
      return {'success': false, 'message': 'common.error'};
    }
  }

  /// Turnuvayı sahibi bitirir (status: 'finished'). Süre dolduğunda istemci de bitmiş sayar.
  static Future<bool> finish(String tournamentId) async {
    final me = _auth.currentUser?.uid;
    if (me == null) return false;
    try {
      await _tournaments.doc(tournamentId).update({'status': 'finished'});
      return true;
    } catch (e) {
      debugPrint('Tournament finish error: $e');
      return false;
    }
  }

  /// Kendi turu bittikten sonra skoru gönderir. Kayıt en iyi skor olarak tutulur
  /// ve oynama sayısı bir artar. Kurallarla aynı kısıtları transaction içinde uygular.
  static Future<bool> submitScore({required String tournamentId, required int score}) async {
    final me = _auth.currentUser?.uid;
    if (me == null) return false;
    final ref = _tournaments.doc(tournamentId);
    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final tournament = Tournament.fromDoc(snap);
        if (!tournament.isOpen) return false;

        final mine = tournament.participants[me];
        if (mine == null) return false;

        final newScore = score > mine.score ? score : mine.score;
        tx.update(ref, {
          'participants.$me.score': newScore,
          'participants.$me.plays': mine.plays + 1,
        });
        return true;
      });
    } catch (e) {
      debugPrint('Tournament submit score error: $e');
      return false;
    }
  }

  /// Kullanıcının katıldığı turnuvaları canlı dinler. Indeks değiştiğinde ve her
  /// turnuva dokümanı güncellendiğinde yeni liste yayınlanır.
  static Stream<List<Tournament>> streamMyTournaments(String uid) {
    StreamSubscription? indexSub;
    final tournamentSubs = <String, StreamSubscription>{};
    final latest = <String, Tournament>{};
    late StreamController<List<Tournament>> controller;

    void emit() {
      if (controller.isClosed) return;
      final list = latest.values.toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      controller.add(list);
    }

    controller = StreamController<List<Tournament>>(
      onListen: () {
        indexSub = _userIndex(uid).snapshots().listen((snap) {
          final ids = snap.docs.map((d) => d.id).toSet();

          for (final id in tournamentSubs.keys.toList()) {
            if (!ids.contains(id)) {
              tournamentSubs.remove(id)?.cancel();
              latest.remove(id);
            }
          }

          for (final id in ids) {
            if (tournamentSubs.containsKey(id)) continue;
            tournamentSubs[id] = _tournaments.doc(id).snapshots().listen(
              (doc) {
                if (doc.exists && doc.data() != null) {
                  latest[id] = Tournament.fromDoc(doc);
                } else {
                  latest.remove(id);
                }
                emit();
              },
              onError: (Object e) {
                debugPrint('Tournament stream error ($id): $e');
                latest.remove(id);
                emit();
              },
            );
          }
          emit();
        }, onError: (Object e) {
          debugPrint('Tournament index stream error: $e');
          emit();
        });
      },
      onCancel: () {
        indexSub?.cancel();
        for (final s in tournamentSubs.values) {
          s.cancel();
        }
        tournamentSubs.clear();
      },
    );

    return controller.stream;
  }
}
