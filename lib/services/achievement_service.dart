import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import 'database_helper.dart';
import 'token_service.dart';
import '../widgets/achievement_celebration.dart';
import 'package:emilekbul/services/haptic_service.dart';

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
      id: 'platinum_scholar',
      titleKey: 'achievements.platinum_scholar_title',
      descKey: 'achievements.platinum_scholar_desc',
      icon: Icons.diamond_rounded,
      color: Color(0xFFE5E4E2),
      tokenReward: 500,
      category: 'quiz',
      maxProgress: 500,
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
    const Achievement(
      id: 'duel_champion',
      titleKey: 'achievements.duel_champion_title',
      descKey: 'achievements.duel_champion_desc',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFEAB308),
      tokenReward: 300,
      category: 'duel',
      maxProgress: 50,
    ),
    const Achievement(
      id: 'duel_legend',
      titleKey: 'achievements.duel_legend_title',
      descKey: 'achievements.duel_legend_desc',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFDC2626),
      tokenReward: 600,
      category: 'duel',
      maxProgress: 100,
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
    const Achievement(
      id: 'level_ten',
      titleKey: 'achievements.level_ten_title',
      descKey: 'achievements.level_ten_desc',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFB923C),
      tokenReward: 200,
      category: 'social',
      maxProgress: 10,
    ),
    const Achievement(
      id: 'level_twenty',
      titleKey: 'achievements.level_twenty_title',
      descKey: 'achievements.level_twenty_desc',
      icon: Icons.bolt_rounded,
      color: Color(0xFFF43F5E),
      tokenReward: 400,
      category: 'social',
      maxProgress: 20,
    ),
    const Achievement(
      id: 'streak_week',
      titleKey: 'achievements.streak_week_title',
      descKey: 'achievements.streak_week_desc',
      icon: Icons.whatshot_rounded,
      color: Color(0xFFF97316),
      tokenReward: 70,
      category: 'social',
      maxProgress: 7,
    ),
    const Achievement(
      id: 'streak_month',
      titleKey: 'achievements.streak_month_title',
      descKey: 'achievements.streak_month_desc',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFEF4444),
      tokenReward: 300,
      category: 'social',
      maxProgress: 30,
    ),
    const Achievement(
      id: 'recruiter',
      titleKey: 'achievements.recruiter_title',
      descKey: 'achievements.recruiter_desc',
      icon: Icons.person_add_alt_1_rounded,
      color: Color(0xFF22D3EE),
      tokenReward: 100,
      category: 'social',
      maxProgress: 1,
    ),
    const Achievement(
      id: 'ambassador',
      titleKey: 'achievements.ambassador_title',
      descKey: 'achievements.ambassador_desc',
      icon: Icons.campaign_rounded,
      color: Color(0xFF8B5CF6),
      tokenReward: 400,
      category: 'social',
      maxProgress: 5,
    ),
    const Achievement(
      id: 'collector',
      titleKey: 'achievements.collector_title',
      descKey: 'achievements.collector_desc',
      icon: Icons.collections_rounded,
      color: Color(0xFFEC4899),
      tokenReward: 250,
      category: 'social',
      maxProgress: 10,
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

  /// Firestore'daki açılmış/ödülü alınmış rozetleri yerel kayıtlarla birleştirir.
  static Future<void> importState({required List<String> unlocked, required List<String> claimed}) async {
    if (unlocked.isNotEmpty) {
      final db = await DatabaseHelper.instance.database;
      final localUnlocked = (await getUnlockedAchievements()).toSet();
      for (final id in unlocked) {
        if (localUnlocked.contains(id)) continue;
        await db.insert('achievements', {
          'id': id,
          'unlocked_at': DateTime.now().toIso8601String(),
        });
      }
    }
    if (claimed.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final localClaimed = prefs.getStringList(_claimedKey) ?? [];
      final merged = {...localClaimed, ...claimed}.toList();
      if (merged.length != localClaimed.length) {
        await prefs.setStringList(_claimedKey, merged);
      }
    }
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

    AnalyticsService.logAchievementUnlocked(achievementId: id);

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
        HapticService.medium();
        AchievementCelebration.show(context, achievement);
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
      await TokenService.addTokens(achievement.tokenReward, source: 'achievement');

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
        HapticService.heavy();
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
    if (count >= 500) {
      if (!context.mounted) return;
      await unlockAchievement('platinum_scholar', context);
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
    if (wins >= 50) {
      if (!context.mounted) return;
      await unlockAchievement('duel_champion', context);
    }
    if (wins >= 100) {
      if (!context.mounted) return;
      await unlockAchievement('duel_legend', context);
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
    if (level >= 10) {
      if (!context.mounted) return;
      await unlockAchievement('level_ten', context);
    }
    if (level >= 20) {
      if (!context.mounted) return;
      await unlockAchievement('level_twenty', context);
    }
  }

  static Future<void> checkAndUnlockStreakAchievements(int streak, BuildContext context) async {
    if (streak >= 7) {
      if (!context.mounted) return;
      await unlockAchievement('streak_week', context);
    }
    if (streak >= 30) {
      if (!context.mounted) return;
      await unlockAchievement('streak_month', context);
    }
  }

  static Future<void> checkAndUnlockReferralAchievements(int referralCount, BuildContext context) async {
    if (referralCount >= 1) {
      if (!context.mounted) return;
      await unlockAchievement('recruiter', context);
    }
    if (referralCount >= 5) {
      if (!context.mounted) return;
      await unlockAchievement('ambassador', context);
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
        if (totalOwned >= 10) {
          if (!context.mounted) return;
          await unlockAchievement('collector', context);
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
