import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'token_service.dart';

class Achievement {
  final String id;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;
  final int tokenReward;
  final String category; // 'quiz', 'duel', 'social'
  final int maxProgress;

  const Achievement({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.color,
    this.tokenReward = 50,
    this.category = 'quiz',
    this.maxProgress = 1,
  });
}

class AchievementService {
  static final List<Achievement> achievementsList = [
    // Quiz Başarımları
    const Achievement(
      id: 'first_step',
      titleKey: 'achievements.first_step_title',
      descKey: 'achievements.first_step_desc',
      icon: Icons.flag_rounded,
      color: Color(0xFF10B981),
      tokenReward: 25,
      category: 'quiz',
      maxProgress: 1,
    ),
    const Achievement(
      id: 'bronze_scholar',
      titleKey: 'achievements.bronze_scholar_title',
      descKey: 'achievements.bronze_scholar_desc',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFCD7F32),
      tokenReward: 50,
      category: 'quiz',
      maxProgress: 10,
    ),
    const Achievement(
      id: 'silver_scholar',
      titleKey: 'achievements.silver_scholar_title',
      descKey: 'achievements.silver_scholar_desc',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFC0C0C0),
      tokenReward: 100,
      category: 'quiz',
      maxProgress: 50,
    ),
    const Achievement(
      id: 'gold_scholar',
      titleKey: 'achievements.gold_scholar_title',
      descKey: 'achievements.gold_scholar_desc',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFFFD700),
      tokenReward: 250,
      category: 'quiz',
      maxProgress: 200,
    ),
    const Achievement(
      id: 'perfect_score',
      titleKey: 'achievements.perfect_score_title',
      descKey: 'achievements.perfect_score_desc',
      icon: Icons.stars_rounded,
      color: Color(0xFF06B6D4),
      tokenReward: 40,
      category: 'quiz',
      maxProgress: 1,
    ),
    const Achievement(
      id: 'impossible_master',
      titleKey: 'achievements.impossible_master_title',
      descKey: 'achievements.impossible_master_desc',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFEF4444),
      tokenReward: 150,
      category: 'quiz',
      maxProgress: 1,
    ),

    // Düello Başarımları
    const Achievement(
      id: 'duel_initiate',
      titleKey: 'achievements.duel_initiate_title',
      descKey: 'achievements.duel_initiate_desc',
      icon: Icons.sports_kabaddi_rounded,
      color: Color(0xFF818CF8),
      tokenReward: 30,
      category: 'duel',
      maxProgress: 1,
    ),
    const Achievement(
      id: 'duel_warrior',
      titleKey: 'achievements.duel_warrior_title',
      descKey: 'achievements.duel_warrior_desc',
      icon: Icons.shield_rounded,
      color: Color(0xFFF97316),
      tokenReward: 120,
      category: 'duel',
      maxProgress: 10,
    ),

    // Sosyal & Seviye Başarımları
    const Achievement(
      id: 'friendly',
      titleKey: 'achievements.friendly_title',
      descKey: 'achievements.friendly_desc',
      icon: Icons.people_alt_rounded,
      color: Color(0xFF38BDF8),
      tokenReward: 30,
      category: 'social',
      maxProgress: 1,
    ),
    const Achievement(
      id: 'smart_shopper',
      titleKey: 'achievements.smart_shopper_title',
      descKey: 'achievements.smart_shopper_desc',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFA855F7),
      tokenReward: 75,
      category: 'social',
      maxProgress: 3,
    ),
    const Achievement(
      id: 'level_five',
      titleKey: 'achievements.level_five_title',
      descKey: 'achievements.level_five_desc',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFF59E0B),
      tokenReward: 100,
      category: 'social',
      maxProgress: 5,
    ),
  ];

  static const String _unseenKey = 'unseen_achievements';
  static const String _claimedKey = 'claimed_achievement_rewards';

  /// Kilidi açılmış tüm başarımların ID'lerini yerel veritabanından çeker
  static Future<List<String>> getUnlockedAchievements() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('achievements');
    return maps.map((map) => map['id'] as String).toList();
  }

  /// Ödülü alınmış tüm başarımların ID'lerini çeker
  static Future<List<String>> getClaimedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_claimedKey) ?? [];
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

    // Kullanıcıya bildirim göster
    try {
      final achievement = achievementsList.firstWhere((a) => a.id == id);
      if (context.mounted) {
        HapticFeedback.mediumImpact();
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
    } catch (_) {}
  }

  /// Başarım ödülünü talep et
  static Future<bool> claimReward(String id, BuildContext context) async {
    try {
      final achievement = achievementsList.firstWhere((a) => a.id == id);
      final prefs = await SharedPreferences.getInstance();
      final claimedList = prefs.getStringList(_claimedKey) ?? [];

      if (claimedList.contains(id)) return false;

      // Jeton ekle
      await TokenService.addTokens(achievement.tokenReward);

      // Claimed listesine ekle
      claimedList.add(id);
      await prefs.setStringList(_claimedKey, claimedList);

      // Firestore'u güncelle
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'claimedBadges': FieldValue.arrayUnion([id]),
          });
        } catch (e) {
          debugPrint('Error updating claimedBadges in Firestore: $e');
        }
      }

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'achievements.reward_claimed_toast'.tr(args: [achievement.tokenReward.toString()]),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error claiming achievement reward: $e');
      return false;
    }
  }

  /// Çözülen test sayısına göre başarımları kontrol eder
  static Future<void> checkAndUnlockTestCountAchievements(int count, BuildContext context) async {
    if (count >= 1) {
      if (!context.mounted) return;
      await unlockAchievement('first_step', context);
    }
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

  /// Kusursuz test başarımı
  static Future<void> checkAndUnlockPerfectScore(int score, int total, BuildContext context) async {
    if (total > 0 && score == total) {
      if (!context.mounted) return;
      await unlockAchievement('perfect_score', context);
    }
  }

  /// İmkansız modda tam puan alıp almadığını kontrol eder
  static Future<void> checkAndUnlockImpossibleMaster(
      String difficulty, int score, int total, BuildContext context) async {
    if ((difficulty == 'Imkansız' || difficulty.toLowerCase() == 'impossible') && total > 0 && score == total) {
      if (!context.mounted) return;
      await unlockAchievement('impossible_master', context);
    }
  }

  /// Düello galibiyetlerine göre başarımları kontrol eder
  static Future<void> checkAndUnlockDuelAchievements(int wins, BuildContext context) async {
    if (wins >= 1) {
      if (!context.mounted) return;
      await unlockAchievement('duel_initiate', context);
    }
    if (wins >= 10) {
      if (!context.mounted) return;
      await unlockAchievement('duel_warrior', context);
    }
  }

  /// Arkadaş sayısına göre başarımları kontrol eder
  static Future<void> checkAndUnlockSocialAchievements(int friendsCount, BuildContext context) async {
    if (friendsCount >= 1) {
      if (!context.mounted) return;
      await unlockAchievement('friendly', context);
    }
  }

  /// Seviyeye göre başarımları kontrol eder
  static Future<void> checkAndUnlockLevelAchievements(int level, BuildContext context) async {
    if (level >= 5) {
      if (!context.mounted) return;
      await unlockAchievement('level_five', context);
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
        final List<dynamic> ownedFrames = data['ownedFrames'] ?? [];
        final List<dynamic> ownedTitles = data['ownedTitles'] ?? [];
        final List<dynamic> ownedAvatars = data['ownedAvatars'] ?? [];
        final int validFrames = ownedFrames.where((f) => f != '0' && f != 'yok' && f.toString().isNotEmpty).length;
        final int validTitles = ownedTitles.where((t) => t != '0' && t != 'yok' && t.toString().isNotEmpty).length;
        final int validAvatars = ownedAvatars.where((a) => a != '0' && a != 'yok' && a.toString().isNotEmpty).length;
        final int totalOwned = validFrames + validTitles + validAvatars;
        if (totalOwned >= 3) {
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
