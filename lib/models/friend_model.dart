import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  none,
  friends,
  sentPending,
  receivedPending,
}

class FriendUser {
  final String uid;
  final String username;
  final String avatarIndex;
  final String equippedFrame;
  final String equippedTitle;
  final int level;
  final int totalPoints;
  final DateTime? addedAt;

  const FriendUser({
    required this.uid,
    required this.username,
    this.avatarIndex = '0',
    this.equippedFrame = '0',
    this.equippedTitle = 'yok',
    this.level = 1,
    this.totalPoints = 0,
    this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'avatarIndex': avatarIndex,
      'equippedFrame': equippedFrame,
      'equippedTitle': equippedTitle,
      'level': level,
      'totalPoints': totalPoints,
      'addedAt': addedAt != null ? Timestamp.fromDate(addedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory FriendUser.fromMap(Map<String, dynamic> map, String docId) {
    return FriendUser(
      uid: docId.isNotEmpty ? docId : (map['uid']?.toString() ?? ''),
      username: map['username']?.toString() ?? '',
      avatarIndex: map['avatarIndex']?.toString() ?? '0',
      equippedFrame: map['equippedFrame']?.toString() ?? '0',
      equippedTitle: map['equippedTitle']?.toString() ?? 'yok',
      level: (map['level'] as num?)?.toInt() ?? 1,
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
      addedAt: (map['addedAt'] is Timestamp) ? (map['addedAt'] as Timestamp).toDate() : null,
    );
  }

  factory FriendUser.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return FriendUser.fromMap(data, doc.id);
  }
}

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromUsername;
  final String fromAvatarIndex;
  final String fromEquippedFrame;
  final String fromEquippedTitle;
  final String toUsername;
  final String toAvatarIndex;
  final String toEquippedFrame;
  final String toEquippedTitle;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime? createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromUsername,
    this.fromAvatarIndex = '0',
    this.fromEquippedFrame = '0',
    this.fromEquippedTitle = 'yok',
    required this.toUsername,
    this.toAvatarIndex = '0',
    this.toEquippedFrame = '0',
    this.toEquippedTitle = 'yok',
    this.status = 'pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'fromUsername': fromUsername,
      'fromAvatarIndex': fromAvatarIndex,
      'fromEquippedFrame': fromEquippedFrame,
      'fromEquippedTitle': fromEquippedTitle,
      'toUsername': toUsername,
      'toAvatarIndex': toAvatarIndex,
      'toEquippedFrame': toEquippedFrame,
      'toEquippedTitle': toEquippedTitle,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory FriendRequest.fromDoc(DocumentSnapshot doc) {
    final map = (doc.data() as Map<String, dynamic>?) ?? {};
    return FriendRequest(
      id: doc.id,
      fromUid: map['fromUid']?.toString() ?? '',
      toUid: map['toUid']?.toString() ?? '',
      fromUsername: map['fromUsername']?.toString() ?? '',
      fromAvatarIndex: map['fromAvatarIndex']?.toString() ?? '0',
      fromEquippedFrame: map['fromEquippedFrame']?.toString() ?? '0',
      fromEquippedTitle: map['fromEquippedTitle']?.toString() ?? 'yok',
      toUsername: map['toUsername']?.toString() ?? '',
      toAvatarIndex: map['toAvatarIndex']?.toString() ?? '0',
      toEquippedFrame: map['toEquippedFrame']?.toString() ?? '0',
      toEquippedTitle: map['toEquippedTitle']?.toString() ?? 'yok',
      status: map['status']?.toString() ?? 'pending',
      createdAt: (map['createdAt'] is Timestamp) ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
