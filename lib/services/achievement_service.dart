import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class Achievement {
  final String id;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;

  Achievement({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.color,
  });
}

class AchievementService {
  static final List<Achievement> achievementsList = [
    Achievement(
      id: 'bronze_scholar',
      titleKey: 'achievements.bronze_scholar_title',
      descKey: 'achievements.bronze_scholar_desc',
      icon: Icons.military_tech_rounded,
      color: Colors.brown.shade400,
    ),
    Achievement(
      id: 'silver_scholar',
      titleKey: 'achievements.silver_scholar_title',
      descKey: 'achievements.silver_scholar_desc',
      icon: Icons.military_tech_rounded,
      color: Colors.grey.shade400,
    ),
    Achievement(
      id: 'gold_scholar',
      titleKey: 'achievements.gold_scholar_title',
      descKey: 'achievements.gold_scholar_desc',
      icon: Icons.military_tech_rounded,
      color: Colors.amber.shade600,
    ),
    Achievement(
      id: 'impossible_master',
      titleKey: 'achievements.impossible_master_title',
      descKey: 'achievements.impossible_master_desc',
      icon: Icons.workspace_premium_rounded,
      color: Colors.redAccent,
    ),
    Achievement(
      id: 'smart_shopper',
      titleKey: 'achievements.smart_shopper_title',
      descKey: 'achievements.smart_shopper_desc',
      icon: Icons.shopping_bag_rounded,
      color: Colors.purpleAccent,
    ),
  ];

  static const String _unseenKey = 'unseen_achievements';

  /// Kilidi açılmış tüm başarımların ID'lerini yerel veritabanından çeker
  static Future<List<String>> getUnlockedAchievements() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('achievements');
    return maps.map((map) => map['id'] as String).toList();
  }

  /// Bir başarımın kilidini açar (hem yerel DB hem de Firestore güncellemesi)
  static Future<void> unlockAchievement(String id, BuildContext context) async {
    final db = await DatabaseHelper.instance.database;
    
    // Zaten açık mı kontrol et
    final List<Map<String, dynamic>> existing = await db.query(
      'achievements',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (existing.isNotEmpty) return;

    // Yerel DB'ye kaydet
    await db.insert('achievements', {
      'id': id,
      'unlocked_at': DateTime.now().toIso8601String(),
    });

    // Firestore'a kaydet
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.update({
          'unlockedBadges': FieldValue.arrayUnion([id]),
        });
      } catch (e) {
        debugPrint('Error updating Firestore achievements: $e');
      }
    }

    // Unseen (Yeni) olarak SharedPreferences'a ekle
    final prefs = await SharedPreferences.getInstance();
    final unseenList = prefs.getStringList(_unseenKey) ?? [];
    if (!unseenList.contains(id)) {
      unseenList.add(id);
      await prefs.setStringList(_unseenKey, unseenList);
    }

    // Kullanıcıya harika bir bildirim göster
    final achievement = achievementsList.firstWhere((a) => a.id == id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(achievement.icon, color: achievement.color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'achievements.unlocked_toast'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent),
                    ),
                    Text(
                      achievement.titleKey.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  /// Çözülen test sayısına göre başarımları kontrol eder
  static Future<void> checkAndUnlockTestCountAchievements(int count, BuildContext context) async {
    if (count >= 10) {
      if (!context.mounted) return;
      await unlockAchievement('bronze_scholar', context);
    }
    if (count >= 50) {
      if (!context.mounted) return;
      await unlockAchievement('silver_scholar', context);
    }
    if (count >= 200) {
      if (!context.mounted) return;
      await unlockAchievement('gold_scholar', context);
    }
  }

  /// İmkansız modda tam puan alıp almadığını kontrol eder
  static Future<void> checkAndUnlockImpossibleMaster(
      String difficulty, int score, int total, BuildContext context) async {
    if (difficulty == 'Imkansız' && score == total) {
      await unlockAchievement('impossible_master', context);
    }
  }

  /// Satın alınan eşya sayısına göre kontrol eder
  static Future<void> checkAndUnlockSmartShopper(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data != null) {
        final List<dynamic> purchasedFrames = data['purchasedFrames'] ?? [];
        final List<dynamic> purchasedTitles = data['purchasedTitles'] ?? [];
        final int totalPurchases = purchasedFrames.length + purchasedTitles.length;
        if (totalPurchases >= 3) {
          if (!context.mounted) return;
          await unlockAchievement('smart_shopper', context);
        }
      }
    } catch (e) {
      debugPrint('Error checking smart shopper achievement: $e');
    }
  }

  /// Aktif rozeti ayarlar (hem Firestore hem de SharedPreferences)
  static Future<void> setActiveBadge(String? badgeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.update({
          'activeBadge': badgeId,
        });
      } catch (e) {
        debugPrint('Error setting active badge in Firestore: $e');
      }
    }
  }

  /// Rozet detaylarını döner
  static Achievement? getBadgeDetails(String? id) {
    if (id == null) return null;
    try {
      return achievementsList.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Görülmemiş (yeni) rozetlerin listesini döner
  static Future<List<String>> getUnseenAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unseenKey) ?? [];
  }

  /// Bir rozeti görüldü olarak işaretler
  static Future<void> markAsSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unseenList = prefs.getStringList(_unseenKey) ?? [];
    if (unseenList.contains(id)) {
      unseenList.remove(id);
      await prefs.setStringList(_unseenKey, unseenList);
    }
  }

  /// Görülmemiş rozet var mı?
  static Future<bool> hasUnseenAchievements() async {
    final list = await getUnseenAchievements();
    return list.isNotEmpty;
  }
}
