import 'package:cloud_firestore/cloud_firestore.dart';
import 'question.dart';

class DuelPlayer {
  final String uid;
  final String username;
  final String avatarIndex;
  final String equippedFrame;
  final String equippedTitle;
  final int tokens;
  final String language;
  final bool isReady;
  final int score;
  final int progress;
  final bool finished;
  final int finishTime; // Milliseconds taken to finish
  final List<int?> userAnswers;

  DuelPlayer({
    required this.uid,
    required this.username,
    required this.avatarIndex,
    required this.equippedFrame,
    required this.equippedTitle,
    required this.tokens,
    this.language = 'tr',
    this.isReady = false,
    this.score = 0,
    this.progress = 0,
    this.finished = false,
    this.finishTime = 0,
    this.userAnswers = const [],
  });

  factory DuelPlayer.fromMap(Map<dynamic, dynamic> map) {
    return DuelPlayer(
      uid: map['uid']?.toString() ?? '',
      username: map['username']?.toString() ?? 'Oyuncu',
      avatarIndex: map['avatarIndex']?.toString() ?? '0',
      equippedFrame: map['equippedFrame']?.toString() ?? '0',
      equippedTitle: map['equippedTitle']?.toString() ?? 'yok',
      tokens: (map['tokens'] as num?)?.toInt() ?? 0,
      language: map['language']?.toString() ?? 'tr',
      isReady: map['isReady'] == true,
      score: (map['score'] as num?)?.toInt() ?? 0,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      finished: map['finished'] == true,
      finishTime: (map['finishTime'] as num?)?.toInt() ?? 0,
      userAnswers: (map['userAnswers'] as List<dynamic>?)
              ?.map((e) => (e as num?)?.toInt())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'avatarIndex': avatarIndex,
      'equippedFrame': equippedFrame,
      'equippedTitle': equippedTitle,
      'tokens': tokens,
      'language': language,
      'isReady': isReady,
      'score': score,
      'progress': progress,
      'finished': finished,
      'finishTime': finishTime,
      'userAnswers': userAnswers,
    };
  }

  DuelPlayer copyWith({
    String? uid,
    String? username,
    String? avatarIndex,
    String? equippedFrame,
    String? equippedTitle,
    int? tokens,
    String? language,
    bool? isReady,
    int? score,
    int? progress,
    bool? finished,
    int? finishTime,
    List<int?>? userAnswers,
  }) {
    return DuelPlayer(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      equippedFrame: equippedFrame ?? this.equippedFrame,
      equippedTitle: equippedTitle ?? this.equippedTitle,
      tokens: tokens ?? this.tokens,
      language: language ?? this.language,
      isReady: isReady ?? this.isReady,
      score: score ?? this.score,
      progress: progress ?? this.progress,
      finished: finished ?? this.finished,
      finishTime: finishTime ?? this.finishTime,
      userAnswers: userAnswers ?? this.userAnswers,
    );
  }
}

class DuelConfig {
  final String category;
  final int questionCount;
  final int betTokens;
  final String difficulty;

  const DuelConfig({
    this.category = 'Genel Kültür',
    this.questionCount = 5,
    this.betTokens = 50,
    this.difficulty = 'Orta',
  });

  factory DuelConfig.fromMap(Map<dynamic, dynamic> map) {
    return DuelConfig(
      category: map['category']?.toString() ?? 'Genel Kültür',
      questionCount: (map['questionCount'] as num?)?.toInt() ?? 5,
      betTokens: (map['betTokens'] as num?)?.toInt() ?? 50,
      difficulty: map['difficulty']?.toString() ?? 'Orta',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'questionCount': questionCount,
      'betTokens': betTokens,
      'difficulty': difficulty,
    };
  }

  DuelConfig copyWith({
    String? category,
    int? questionCount,
    int? betTokens,
    String? difficulty,
  }) {
    return DuelConfig(
      category: category ?? this.category,
      questionCount: questionCount ?? this.questionCount,
      betTokens: betTokens ?? this.betTokens,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}

class DuelRoom {
  final String roomCode;
  final String hostUid;
  final DuelPlayer host;
  final DuelPlayer? guest;
  final DuelPlayer? pendingGuest; // Katılma isteği gönderen misafir
  final String? joinRequestStatus; // 'none', 'pending', 'approved', 'rejected'
  final String status; // 'waiting', 'ready', 'starting', 'in_game', 'finished', 'closed'
  final DuelConfig config;
  final List<Question> questions;
  final String? winnerUid;
  final int prizeTokens;
  final bool hostWantsToStart;
  final DateTime? createdAt;

  DuelRoom({
    required this.roomCode,
    required this.hostUid,
    required this.host,
    this.guest,
    this.pendingGuest,
    this.joinRequestStatus,
    required this.status,
    required this.config,
    this.questions = const [],
    this.winnerUid,
    this.prizeTokens = 0,
    this.hostWantsToStart = false,
    this.createdAt,
  });

  factory DuelRoom.fromMap(Map<dynamic, dynamic> map, String docId) {
    final hostRaw = map['host'];
    final guestRaw = map['guest'];
    final pendingGuestRaw = map['pendingGuest'];
    final configRaw = map['config'];
    final questionsRaw = map['questions'];
    final createdAtRaw = map['createdAt'];

    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw != null) {
      createdAt = DateTime.tryParse(createdAtRaw.toString());
    }

    return DuelRoom(
      roomCode: docId,
      hostUid: map['hostUid']?.toString() ?? '',
      host: hostRaw is Map
          ? DuelPlayer.fromMap(hostRaw)
          : DuelPlayer(
              uid: '',
              username: 'Oyuncu',
              avatarIndex: '0',
              equippedFrame: '0',
              equippedTitle: 'yok',
              tokens: 0,
            ),
      guest: guestRaw is Map ? DuelPlayer.fromMap(guestRaw) : null,
      pendingGuest: pendingGuestRaw is Map ? DuelPlayer.fromMap(pendingGuestRaw) : null,
      joinRequestStatus: map['joinRequestStatus']?.toString(),
      status: map['status']?.toString() ?? 'waiting',
      config: configRaw is Map ? DuelConfig.fromMap(configRaw) : const DuelConfig(),
      questions: (questionsRaw as List<dynamic>?)
              ?.map((q) => Question.fromJson(q is Map ? q : {}))
              .toList() ??
          const [],
      winnerUid: map['winnerUid']?.toString(),
      prizeTokens: (map['prizeTokens'] as num?)?.toInt() ?? 0,
      hostWantsToStart: map['hostWantsToStart'] == true,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'hostUid': hostUid,
      'host': host.toMap(),
      'guest': guest?.toMap(),
      'pendingGuest': pendingGuest?.toMap(),
      'joinRequestStatus': joinRequestStatus,
      'status': status,
      'config': config.toMap(),
      'questions': questions.map((q) => q.toJson()).toList(),
      'winnerUid': winnerUid,
      'prizeTokens': prizeTokens,
      'hostWantsToStart': hostWantsToStart,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  /// Bahis Havuzu ve Kademeli Komisyon Oranları:
  /// 10 - 50: %20 Komisyon
  /// 100: %16 Komisyon
  /// 250: %14 Komisyon
  /// 500: %12 Komisyon
  /// 1000: %10 Komisyon (1K özel yüksek bahis)
  static double getCommissionRate(int betTokens) {
    if (betTokens >= 1000) return 0.10; // %10 kesinti
    if (betTokens >= 500) return 0.12;  // %12 kesinti
    if (betTokens >= 250) return 0.14;  // %14 kesinti
    if (betTokens >= 100) return 0.16;  // %16 kesinti
    return 0.20;                        // %20 kesinti
  }

  /// Hesaplanan Net Ödül: Toplam Havuzdan kademeli komisyon kesintisi
  static int calculatePrize(int betTokens) {
    final totalPot = betTokens * 2;
    final commission = getCommissionRate(betTokens);
    return (totalPot * (1.0 - commission)).round();
  }

  /// Yüksek / Özel Bahis mi? (Botların oynamayacağı özel kademe)
  static bool isSpecialHighBet(int betTokens) {
    return betTokens >= 250;
  }
}

class DuelChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String type; // 'text', 'quick', 'emoji'
  final String? phraseKey;
  final DateTime? createdAt;

  const DuelChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    this.type = 'text',
    this.phraseKey,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'type': type,
      'phraseKey': phraseKey,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory DuelChatMessage.fromDoc(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? {};
    return DuelChatMessage(
      id: doc.id,
      senderUid: map['senderUid']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'Oyuncu',
      senderAvatar: map['senderAvatar']?.toString() ?? '0',
      text: map['text']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      phraseKey: map['phraseKey']?.toString(),
      createdAt: (map['createdAt'] is Timestamp) ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
