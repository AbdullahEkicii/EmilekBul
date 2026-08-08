import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Kullanıcı profil modeli
  static const String usersCollection = 'users';

  /// Yeni kullanıcı kaydetme (register sonrası çağrılır)
  static Future<bool> createUserProfile({
    required String uid,
    required String email,
    String username = '',
    String firstName = '',
    String lastName = '',
    String avatarIndex = '1',
  }) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).set({
        'email': email,
        'username': username,
        'username_lower': username.toLowerCase().trim(),
        'firstName': firstName,
        'lastName': lastName,
        'avatarIndex': avatarIndex,
        'isEmailVerified': true, // E-posta doğrulanmış sayıyoruz artık
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tokens': 50, // Default start token
        'level': 1,
        'completedQuizzes': 0,
        'ownedAvatars': [avatarIndex],
        'ownedFrames': ['0'],
        'ownedTitles': ['0'],
        'equippedFrame': '0',
        'equippedTitle': 'yok',
      });
      return true;
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      return false;
    }
  }

  static Future<void> linkPlayGamesProfile(String? id, String? name) async {
    final user = _auth.currentUser;
    if (user != null && id != null) {
      await _firestore.collection(usersCollection).doc(user.uid).set({
        'playGamesId': id,
        'username': name ?? 'Player', // Update username to Play Games name
        'username_lower': (name ?? 'Player').toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static Future<List<Map<String, dynamic>>> getTopUsersByCategory(
    String category, {
    int limit = 10,
  }) async {
    final now = DateTime.now();
    final yearMonth = "${now.year}_${now.month.toString().padLeft(2, '0')}";
    debugPrint("SORGULANIYOR: Kategori: $category, Ay: $yearMonth");

    // Eğer kategori 'Genel' ise totalPoints'e göre çek
    Query<Map<String, dynamic>> query = _firestore
        .collection('monthly_scores')
        .doc(yearMonth)
        .collection('scores');

    if (category == 'Genel') {
      query = query
          .where('totalPoints', isGreaterThan: 0)
          .orderBy('totalPoints', descending: true);
    } else {
      query = query
          .where('categoryPoints.$category', isGreaterThan: 0)
          .orderBy('categoryPoints.$category', descending: true);
    }

    final querySnapshot = await query.limit(limit).get();
    debugPrint("SONUÇ: ${querySnapshot.docs.length} kullanıcı bulundu.");

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      final categoryPoints =
          data['categoryPoints'] as Map<String, dynamic>? ?? {};

      int points = 0;
      if (category == 'Genel') {
        points = data['totalPoints'] ?? 0;
      } else {
        points = categoryPoints[category] ?? 0;
      }

      return {
        'uid': doc.id,
        'username': data['username'] ?? 'Bilinmeyen',
        'points': points,
        'avatarIndex': data['avatarIndex'] ?? '0',
        'equippedFrame': data['equippedFrame'] ?? '0',
        'equippedTitle': data['equippedTitle'] ?? 'yok',
      };
    }).toList();
  }

  /// Top 5 + Mevcut Kullanıcı verisini getirir
  static Future<List<Map<String, dynamic>>> getTopUsersWithContext(
      String category) async {
    final uid = _auth.currentUser?.uid;
    List<Map<String, dynamic>> top5 =
        await getTopUsersByCategory(category, limit: 5);

    // Listedeki TÜM kullanıcıların güncel profil verilerini (Frame, Avatar, Title, Badge) users koleksiyonundan yükle
    for (int i = 0; i < top5.length; i++) {
      final userUid = top5[i]['uid'];
      if (userUid != null) {
        final profile = await getUserProfile(userUid);
        if (profile != null) {
          top5[i]['username'] = profile['username'] ?? top5[i]['username'];
          top5[i]['avatarIndex'] = profile['avatarIndex'] ?? top5[i]['avatarIndex'];
          top5[i]['equippedFrame'] = profile['equippedFrame'] ?? top5[i]['equippedFrame'];
          top5[i]['equippedTitle'] = profile['equippedTitle'] ?? top5[i]['equippedTitle'];
          top5[i]['activeBadge'] = profile['activeBadge'] ?? top5[i]['activeBadge'];
        }
      }
    }

    // Eğer oturum açmış kullanıcı ilk 5'te yoksa, sıralamasıyla beraber sona ekle
    if (uid != null) {
      bool isUserInTop5 = top5.any((user) => user['uid'] == uid);
      if (!isUserInTop5) {
        final myProfile = await getUserProfile(uid);
        if (myProfile != null) {
          final rank = await getUserRank(uid, category); // Pass category

          int points = 0;
          if (category == 'Genel') {
            final monthlyPoints = await getUserMonthlyPoints(uid);
            points = monthlyPoints;
          } else {
            final now = DateTime.now();
            final yearMonth =
                "${now.year}_${now.month.toString().padLeft(2, '0')}";
            final monthlyDoc = await _firestore
                .collection('monthly_scores')
                .doc(yearMonth)
                .collection('scores')
                .doc(uid)
                .get();
            if (monthlyDoc.exists) {
              final cats = monthlyDoc.data()?['categoryPoints']
                      as Map<String, dynamic>? ??
                  {};
              points = cats[category] ?? 0;
            }
          }

          top5.add({
            'uid': uid,
            'username': myProfile['username'] ?? 'Siz',
            'points': points,
            'avatarIndex': myProfile['avatarIndex'] ?? '0',
            'equippedFrame': myProfile['equippedFrame'] ?? '0',
            'equippedTitle': myProfile['equippedTitle'] ?? 'yok',
            'activeBadge': myProfile['activeBadge'],
            'rank': rank,
          });
        }
      }
    }

    return top5;
  }

// ... (skip intermediate methods if not changing them, but I need to link to getUserRank at the end, so I will target getUserRank directly in a separate call or try to verify where it is relative to this block. It is at the end of the file. I will use MultiReplace to do both.)

  static Future<void> addPointsToUser({
    required String uid,
    required String category,
    required int pointsToAdd,
    required String difficulty,
  }) async {
    final userRef = _firestore.collection(usersCollection).doc(uid);
    final now = DateTime.now();
    final yearMonth = "${now.year}_${now.month.toString().padLeft(2, '0')}";
    final monthlyStatsRef = _firestore
        .collection('monthly_scores')
        .doc(yearMonth)
        .collection('scores')
        .doc(uid);

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Önce tüm OKUMA (Read) işlemlerini yap
        final userSnapshot = await transaction.get(userRef);
        final monthlySnapshot = await transaction.get(monthlyStatsRef);

        if (!userSnapshot.exists) {
          debugPrint("HATA: Kullanıcı profili bulunamadı! UID: $uid");
          return;
        }

        final userData = userSnapshot.data() ?? {};

        // 2. Hesaplamaları yap (Local)

        // Global Puanlar
        final totalPoints = (userData['totalPoints'] ?? 0) + pointsToAdd;
        final categoryPoints =
            Map<String, dynamic>.from(userData['categoryPoints'] ?? {});
        categoryPoints[category] =
            (categoryPoints[category] ?? 0) + pointsToAdd;

        // Aylık Puanlar
        int monthlyTotal;
        Map<String, dynamic> monthlyCats;
        bool monthlyExists = monthlySnapshot.exists;

        if (monthlyExists) {
          final monthlyData = monthlySnapshot.data() ?? {};
          monthlyTotal = (monthlyData['totalPoints'] ?? 0) + pointsToAdd;
          monthlyCats =
              Map<String, dynamic>.from(monthlyData['categoryPoints'] ?? {});
          monthlyCats[category] = (monthlyCats[category] ?? 0) + pointsToAdd;
        } else {
          monthlyTotal = pointsToAdd;
          monthlyCats = {category: pointsToAdd};
        }

        // 3. En son YAZMA (Write) işlemlerini yap

        // Global güncelleme
        transaction.update(userRef, {
          'totalPoints': totalPoints,
          'categoryPoints': categoryPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Aylık güncelleme
        if (monthlyExists) {
          transaction.update(monthlyStatsRef, {
            'totalPoints': monthlyTotal,
            'categoryPoints': monthlyCats,
            'updatedAt': FieldValue.serverTimestamp(),
            'username': userData['username'],
            'avatarIndex': userData['avatarIndex'],
          });
        } else {
          transaction.set(monthlyStatsRef, {
            'uid': uid,
            'username': userData['username'],
            'avatarIndex': userData['avatarIndex'],
            'totalPoints': monthlyTotal,
            'categoryPoints': monthlyCats,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      debugPrint(
          "BAŞARILI: Puan eklendi. UID: $uid, Kategori: $category, Puan: $pointsToAdd");
    } catch (e) {
      debugPrint("HATA: Puan eklenirken hata oluştu: $e");
      rethrow;
    }
  }

  /// Kullanıcı profilini getirme
  static Future<Map<String, dynamic>?> getUserProfile([String? uid]) async {
    try {
      final userId = uid ?? _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc =
          await _firestore.collection(usersCollection).doc(userId).get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Misafir Girişi
  static Future<UserCredential?> signInAsGuest() async {
    try {
      // 1. Anonim Giriş
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user != null) {
        // 2. Misafir Sayısını Al ve Artır
        final counterRef = _firestore.collection('counters').doc('guest_count');

        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(counterRef);

          int currentCount = 1;
          if (snapshot.exists) {
            currentCount = (snapshot.data()?['count'] ?? 0) + 1;
            transaction.update(counterRef, {'count': currentCount});
          } else {
            transaction.set(counterRef, {'count': currentCount});
          }

          // 3. Kullanıcı Profilini Oluştur
          final username = 'Misafir$currentCount';

          transaction
              .set(_firestore.collection(usersCollection).doc(user.uid), {
            'username': username,
            'username_lower': username.toLowerCase(),
            'firstName': 'Misafir',
            'lastName': '',
            'email': '',
            'avatarIndex': '0',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'totalPoints': 0,
            'totalQuizzes': 0,
            'correctAnswers': 0,
            'level': 1,
            'completedQuizzes': 0,
            'tokens': 50, // Default start token
            'isGuest': true,
            'ownedAvatars': ['0'],
            'ownedFrames': ['0'],
            'ownedTitles': ['0'],
            'equippedFrame': '0',
            'equippedTitle': 'yok',
          });
        });

        // HIZLI JETON EŞİTLEMESİ (Misafir için SharedPreferences güncellemesi)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_tokens', 50);
        } catch (prefError) {
          debugPrint('Error setting guest tokens in SharedPreferences: $prefError');
        }

        return userCredential;
      }
      return null;
    } catch (e) {
      debugPrint('Guest login error: $e');
      return null;
    }
  }

  /// Kullanıcı profilini güncelleme
  static Future<bool> updateUserProfile({
    required String username,
    required String firstName,
    required String lastName,
    required String avatarIndex,
    String? email, // Opsiyonel e-posta parametresi
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      Map<String, dynamic> updateData = {
        'username': username.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'avatarIndex': avatarIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Eğer e-posta parametresi verilmişse ekle
      if (email != null) {
        updateData['email'] = email;
      }

      await _firestore
          .collection(usersCollection)
          .doc(user.uid)
          .update(updateData);

      // Monthly Scores'daki veriyi de güncelle (Avatar/Username değiştiyse)
      final now = DateTime.now();
      final yearMonth = "${now.year}_${now.month.toString().padLeft(2, '0')}";

      try {
        await _firestore
            .collection('monthly_scores')
            .doc(yearMonth)
            .collection('scores')
            .doc(user.uid)
            .update({
          'username': username.trim(),
          'avatarIndex': avatarIndex,
        });
      } catch (e) {
        // Aylık skor henüz yoksa veya hata olursa kritik değil, yoksay
        debugPrint('Error updating monthly score profile data: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return false;
    }
  }

  /// Kullanıcı adının kullanılabilir olup olmadığını kontrol etme
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('username', isEqualTo: username.trim())
          .get();

      // Eğer kullanıcı adı bulundu ama mevcut kullanıcının değilse
      for (var doc in querySnapshot.docs) {
        if (doc.id != currentUser.uid) {
          return false; // Kullanıcı adı zaten kullanılıyor
        }
      }
      return true; // Kullanıcı adı müsait
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

  /// Kullanıcı profilini real-time dinleme
  static Stream<DocumentSnapshot> getUserProfileStream([String? uid]) {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }

    return _firestore.collection(usersCollection).doc(userId).snapshots();
  }

  /// Kullanıcı adına göre kullanıcı arama
  static Future<Map<String, dynamic>?> getUserByUsername(
      String username) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['uid'] = doc.id; // Document ID'yi de ekle
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by username: $e');
      return null;
    }
  }

  /// Kullanıcı profili var mı kontrol et
  static Future<bool> userProfileExists([String? uid]) async {
    try {
      final userId = uid ?? _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc =
          await _firestore.collection(usersCollection).doc(userId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if user profile exists: $e');
      return false;
    }
  }

  /// Profil fotoğrafı path'ini getir
  static String getAvatarPath(String avatarIndex) {
    if (avatarIndex.startsWith('shop_')) {
      return 'lib/assets/avatars/$avatarIndex.jpg';
    }
    final index = int.tryParse(avatarIndex) ?? 0;
    return 'avatars/avatar_${index + 1}.jpg';
  }

  static String getFramePath(String frameId) {
    if (frameId == '0' || frameId == 'yok') return '';
    return 'lib/assets/frames/frame_$frameId.png';
  }

  static Color getFrameColor(String? frameId) {
    switch (frameId) {
      case '1':
        return const Color(0xFFF1C40F); // Gold
      case '2':
        return const Color(0xFF00D2FF); // Neon Blue
      case '3':
        return const Color(0xFFFF416C); // Fiery
      case '4':
        return const Color(0xFFBDC3C7); // Silver
      case '5':
        return const Color(0xFF11998E); // Emerald
      case '6':
        return const Color(0xFFE0EAFC); // Diamond
      case '7':
        return const Color(0xFF00FF87); // Cyber
      case '8':
        return const Color(0xFF2C3E50); // Midnight
      default:
        return Colors.transparent;
    }
  }

  static List<Color> getFrameGradientColors(String? frameId) {
    switch (frameId) {
      case '1': // Gold
        return [
          const Color(0xFFF1C40F),
          const Color(0xFFF39C12),
          const Color(0xFFF1C40F)
        ];
      case '2': // Neon Blue
        return [const Color(0xFF00D2FF), const Color(0xFF3A7BD5)];
      case '3': // Fiery
        return [const Color(0xFFFF416C), const Color(0xFFFF4B2B)];
      case '4': // Silver
        return [const Color(0xFFBDC3C7), const Color(0xFF7F8C8D)];
      case '5': // Emerald
        return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
      case '6': // Diamond
        return [const Color(0xFFE0EAFC), const Color(0xFFCFDEF3)];
      case '7': // Cyber
        return [const Color(0xFF00FF87), const Color(0xFF60EFFF)];
      case '8': // Midnight
        return [
          const Color(0xFF0F2027),
          const Color(0xFF203A43),
          const Color(0xFF2C5364)
        ];
      default:
        return [Colors.transparent, Colors.transparent];
    }
  }

  /// Token miktarını güncelle
  static Future<void> updateUserTokens(int tokens) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection(usersCollection).doc(uid).update({
        'tokens': tokens,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating user tokens in Firestore: $e');
    }
  }

  /// Eşya satın alma
  static Future<Map<String, dynamic>> purchaseItem({
    required String category, // 'avatars', 'frames', 'titles'
    required String itemId,
    required int cost,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return {'success': false, 'message': 'auth.not_logged_in'.tr()};
    }

    final userRef = _firestore.collection(usersCollection).doc(uid);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) {
          return {'success': false, 'message': 'auth.profile_not_found'.tr()};
        }

        final data = snapshot.data()!;
        final currentTokens = data['tokens'] ?? 0;

        if (currentTokens < cost) {
          return {'success': false, 'message': 'shop.insufficient_funds'.tr()};
        }

        String listField = '';
        if (category == 'avatars') {
          listField = 'ownedAvatars';
        } else if (category == 'frames') {
          listField = 'ownedFrames';
        } else if (category == 'titles') {
          listField = 'ownedTitles';
        }

        List<String> owned = List<String>.from(data[listField] ?? []);
        if (owned.contains(itemId)) {
          return {'success': false, 'message': 'shop.already_owned'.tr()};
        }

        owned.add(itemId);
        final int newBalance = currentTokens - cost;
        transaction.update(userRef, {
          'tokens': newBalance,
          listField: FieldValue.arrayUnion([itemId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'message': 'shop.success_message'.tr(),
          'newBalance': newBalance
        };
      });
    } catch (e) {
      return {'success': false, 'message': "${'common.error'.tr()}: $e"};
    }
  }

  /// Eşya kuşanma
  static Future<bool> equipItem(String category, String itemId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      String field = '';
      if (category == 'avatars') {
        field = 'avatarIndex';
      } else if (category == 'frames') {
        field = 'equippedFrame';
      } else if (category == 'titles') {
        field = 'equippedTitle';
      }

      await _firestore.collection(usersCollection).doc(uid).update({
        field: itemId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Monthly Scores'daki veriyi de güncelle (Anlık yansıması için)
      final now = DateTime.now();
      final yearMonth = "${now.year}_${now.month.toString().padLeft(2, '0')}";

      try {
        await _firestore
            .collection('monthly_scores')
            .doc(yearMonth)
            .collection('scores')
            .doc(uid)
            .update({
          field: itemId,
        });
      } catch (e) {
        // Aylık skor henüz yoksa veya hata olursa kritik değil
        debugPrint('Error updating monthly score equipped item: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Equip error: $e');
      return false;
    }
  }

  // ... (existing code) ...

  /// Kullanıcının bu ayki toplam puanını getir
  static Future<int> getUserMonthlyPoints(String uid) async {
    try {
      final now = DateTime.now();
      final yearMonth = "${now.year}_${now.month.toString().padLeft(2, '0')}";

      final doc = await _firestore
          .collection('monthly_scores')
          .doc(yearMonth)
          .collection('scores')
          .doc(uid)
          .get();

      if (doc.exists) {
        return doc.data()?['totalPoints'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting monthly points: $e');
      return 0;
    }
  }

  /// Firebase User nesnesini kullanarak kullanıcının kullanıcı adını Firestore'dan getir
  static Future<String?> getUsernameFromCurrentUser(User? user) async {
    if (user == null) {
      return null; // Kullanıcı yoksa null döndür
    }
    try {
      final doc =
          await _firestore.collection(usersCollection).doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['username']
            as String?; // Firestore'dan kullanıcı adını al
      }
      return null; // Belge yoksa null döndür
    } catch (e) {
      debugPrint('Error getting username from current user: $e');
      return null; // Hata durumunda null döndür
    }
  }

  /// Firebase User nesnesini kullanarak kullanıcının avatarIndex'ini Firestore'dan getir
  static Future<String?> getAvatarIndexFromCurrentUser(User? user) async {
    if (user == null) {
      return null; // Kullanıcı yoksa null döndür
    }
    try {
      final doc =
          await _firestore.collection(usersCollection).doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['avatarIndex'] as String?;
      }
      return null; // Belge yoksa null döndür
    } catch (e) {
      debugPrint('Error getting avatarIndex from current user: $e');
      return null; // Hata durumunda null döndür
    }
  }

  /// Kullanıcının tam adını getir
  static String getFullName(Map<String, dynamic> userData) {
    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      return userData['username'] ?? 'Kullanıcı';
    }

    return '$firstName $lastName'.trim();
  }

  /// Kullanıcının kullanıcı adını getir
  static String getUsername(Map<String, dynamic> userData) {
    return userData['username'] ?? 'Kullanıcı';
  }

  /// Kullanıcı profili silme (hesap silme için)
  static Future<bool> deleteUserProfile([String? uid]) async {
    try {
      final userId = uid ?? _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection(usersCollection).doc(userId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting user profile: $e');
      return false;
    }
  }

  /// En yüksek puanlı kullanıcıyı getir
  static Future<Map<String, dynamic>?> getTopUser() async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .orderBy('totalPoints', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting top user: $e');
      return null;
    }
  }

  /// Aylık kazananı kaydet
  static Future<void> recordMonthlyWinner(
      String yearMonth, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('monthly_winners').doc(yearMonth).set({
        'uid': userData['uid'],
        'username': userData['username'],
        'score': userData['totalPoints'],
        'rewarded': true,
        'rewardAmount': 500,
        'month': yearMonth,
        'scoresReset': false, // Yeni: Sıfırlama durumunu takip et
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error recording monthly winner: $e');
    }
  }

  /// Kazananın ödülünü ver (Token ekle)
  static Future<void> giveReward(String uid, int amount) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).update({
        'tokens': FieldValue.increment(amount),
      });
    } catch (e) {
      debugPrint('Error giving reward: $e');
    }
  }

  // Eski Reset fonksiyonları kaldırıldı (Artık aylık bucket sistemi kullanılıyor)

  /// Belirli bir ayın kazanan verisini getir
  static Future<Map<String, dynamic>?> getMonthlyWinnerData(
      String yearMonth) async {
    try {
      final doc =
          await _firestore.collection('monthly_winners').doc(yearMonth).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting monthly winner data: $e');
      return null;
    }
  }

  /// Bu ayın kazananı belirlendi mi kontrol et
  static Future<bool> isWinnerDetermined(String yearMonth) async {
    final doc =
        await _firestore.collection('monthly_winners').doc(yearMonth).get();
    return doc.exists;
  }

  /// Son ayın kazananını getir
  static Future<Map<String, dynamic>?> getLastMonthWinner() async {
    try {
      final querySnapshot = await _firestore
          .collection('monthly_winners')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last winner: $e');
      return null;
    }
  }

  /// Kullanıcının sıralamasını hesapla (Aylık)
  static Future<int> getUserRank(String uid, String category) async {
    try {
      final now = DateTime.now();
      final yearMonth = "${now.year}_${now.month.toString().padLeft(2, '0')}";

      final monthlyDoc = await _firestore
          .collection('monthly_scores')
          .doc(yearMonth)
          .collection('scores')
          .doc(uid)
          .get();

      if (!monthlyDoc.exists) return 0;

      int myPoints = 0;
      if (category == 'Genel') {
        myPoints = monthlyDoc.data()?['totalPoints'] ?? 0;
      } else {
        final cats =
            monthlyDoc.data()?['categoryPoints'] as Map<String, dynamic>? ?? {};
        myPoints = cats[category] ?? 0;
      }

      // Bu ay benden yüksek puanı olanları say
      Query query = _firestore
          .collection('monthly_scores')
          .doc(yearMonth)
          .collection('scores');

      if (category == 'Genel') {
        query = query.where('totalPoints', isGreaterThan: myPoints);
      } else {
        query =
            query.where('categoryPoints.$category', isGreaterThan: myPoints);
      }

      final countQuery = await query.count().get();

      return countQuery.count! + 1;
    } catch (e) {
      debugPrint('Rank calculation error: $e');
      return 0;
    }
  }

  /// Level calculation: 1->2 (20), 2->3 (50), 3->4 (90) ...
  /// Requirement for level L from L-1 is 10L + 10
  /// Total quizzes T for level L: 5L^2 + 5L - 10
  static int calculateLevel(int completedQuizzes) {
    int level = 1;
    while (completedQuizzes >=
        (5 * (level + 1) * (level + 1) + 5 * (level + 1) - 10)) {
      level++;
    }
    return level;
  }

  static int getQuizzesNeededForNextLevel(int currentLevel) {
    return 5 * (currentLevel + 1) * (currentLevel + 1) +
        5 * (currentLevel + 1) -
        10;
  }

  /// Quiz tamamlandığında quiz sayısını artırır, level ve ödül kontrolü yapar
  static Future<Map<String, dynamic>> incrementCompletedQuizzes(
      String uid) async {
    final userRef = _firestore.collection(usersCollection).doc(uid);
    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return {'levelUp': false};

        final data = snapshot.data()!;
        final int oldQuizzes = data['completedQuizzes'] ?? 0;
        final int newQuizzes = oldQuizzes + 1;
        final int oldLevel = data['level'] ?? 1;
        final int newLevel = calculateLevel(newQuizzes);

        Map<String, dynamic> updates = {
          'completedQuizzes': newQuizzes,
          'totalQuizzes': newQuizzes,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        bool levelUp = false;
        int reward = 0;

        if (newLevel > oldLevel) {
          levelUp = true;
          reward = oldLevel * 100; // Reward for 1->2 is 100, 2->3 is 200 etc.
          updates['level'] = newLevel;
          updates['tokens'] = FieldValue.increment(reward);
        }

        transaction.update(userRef, updates);

        return {
          'levelUp': levelUp,
          'newLevel': newLevel,
          'reward': reward,
          'completedQuizzes': newQuizzes,
        };
      });
    } catch (e) {
      debugPrint('Error incrementing completed quizzes: $e');
      return {'levelUp': false};
    }
  }
}
