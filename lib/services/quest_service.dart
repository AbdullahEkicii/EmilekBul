import 'package:emilekbul/models/quest.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:emilekbul/services/token_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sqflite/sqflite.dart';

class QuestService {
  static const String _dailySolve2Id = 'daily_solve_2_tests';
  static const String _dailyPerfectId = 'daily_perfect_score';
  static const String _dailyDifficultyZorId = 'daily_difficulty_zor';

  static const String _weeklySolve7Id = 'weekly_solve_7_tests';
  static const String _weeklyPerfect3Id = 'weekly_perfect_3_tests';
  static const String _weeklyImpossibleId = 'weekly_any_impossible';

  /// Görevleri başlatır, zamanı geçmiş olanları sıfırlar veya yeniden oluşturur
  static Future<void> initializeQuests() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    // Mevcut tüm görevleri oku
    final List<Map<String, dynamic>> maps = await db.query('quests');
    final Map<String, Quest> existingQuests = {
      for (var map in maps) map['id']: Quest.fromMap(map)
    };

    // Günlük sıfırlama kontrolü
    bool shouldResetDaily = false;
    if (existingQuests.containsKey(_dailySolve2Id)) {
      final lastUpdated = existingQuests[_dailySolve2Id]!.lastUpdated;
      if (lastUpdated.year != now.year ||
          lastUpdated.month != now.month ||
          lastUpdated.day != now.day) {
        shouldResetDaily = true;
      }
    } else {
      shouldResetDaily = true; // Hiç yoksa oluştur
    }

    // Haftalık sıfırlama kontrolü (Pazartesi günü veya farklı haftada sıfırla)
    bool shouldResetWeekly = false;
    if (existingQuests.containsKey(_weeklySolve7Id)) {
      final lastUpdated = existingQuests[_weeklySolve7Id]!.lastUpdated;
      final diffDays = now.difference(lastUpdated).inDays;
      // Eğer farklı bir haftaya geçildiyse veya 7 günden fazla olduysa sıfırla
      if (diffDays >= 7 || _getWeekNumber(now) != _getWeekNumber(lastUpdated)) {
        shouldResetWeekly = true;
      }
    } else {
      shouldResetWeekly = true; // Hiç yoksa oluştur
    }

    // Günlük Görevleri Ekle/Sıfırla
    await _upsertQuest(
      Quest(
        id: _dailySolve2Id,
        type: 'daily',
        targetProgress: 2,
        currentProgress: shouldResetDaily ? 0 : (existingQuests[_dailySolve2Id]?.currentProgress ?? 0),
        rewardTokens: 30,
        isClaimed: shouldResetDaily ? false : (existingQuests[_dailySolve2Id]?.isClaimed ?? false),
        lastUpdated: now,
      ),
    );

    await _upsertQuest(
      Quest(
        id: _dailyPerfectId,
        type: 'daily',
        targetProgress: 1,
        currentProgress: shouldResetDaily ? 0 : (existingQuests[_dailyPerfectId]?.currentProgress ?? 0),
        rewardTokens: 50,
        isClaimed: shouldResetDaily ? false : (existingQuests[_dailyPerfectId]?.isClaimed ?? false),
        lastUpdated: now,
      ),
    );

    await _upsertQuest(
      Quest(
        id: _dailyDifficultyZorId,
        type: 'daily',
        targetProgress: 1,
        currentProgress: shouldResetDaily ? 0 : (existingQuests[_dailyDifficultyZorId]?.currentProgress ?? 0),
        rewardTokens: 40,
        isClaimed: shouldResetDaily ? false : (existingQuests[_dailyDifficultyZorId]?.isClaimed ?? false),
        lastUpdated: now,
      ),
    );

    // Haftalık Görevleri Ekle/Sıfırla
    await _upsertQuest(
      Quest(
        id: _weeklySolve7Id,
        type: 'weekly',
        targetProgress: 7,
        currentProgress: shouldResetWeekly ? 0 : (existingQuests[_weeklySolve7Id]?.currentProgress ?? 0),
        rewardTokens: 100,
        isClaimed: shouldResetWeekly ? false : (existingQuests[_weeklySolve7Id]?.isClaimed ?? false),
        lastUpdated: now,
      ),
    );

    await _upsertQuest(
      Quest(
        id: _weeklyPerfect3Id,
        type: 'weekly',
        targetProgress: 3,
        currentProgress: shouldResetWeekly ? 0 : (existingQuests[_weeklyPerfect3Id]?.currentProgress ?? 0),
        rewardTokens: 150,
        isClaimed: shouldResetWeekly ? false : (existingQuests[_weeklyPerfect3Id]?.isClaimed ?? false),
        lastUpdated: now,
      ),
    );

    await _upsertQuest(
      Quest(
        id: _weeklyImpossibleId,
        type: 'weekly',
        targetProgress: 1,
        currentProgress: shouldResetWeekly ? 0 : (existingQuests[_weeklyImpossibleId]?.currentProgress ?? 0),
        rewardTokens: 200,
        isClaimed: shouldResetWeekly ? false : (existingQuests[_weeklyImpossibleId]?.isClaimed ?? false),
        lastUpdated: now,
      ),
    );
  }

  /// Tek bir görevi veritabanına ekler veya günceller
  static Future<void> _upsertQuest(Quest quest) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'quests',
      quest.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Aktif tüm görevleri listeler
  static Future<List<Quest>> getActiveQuests() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('quests');
    return maps.map((map) => Quest.fromMap(map)).toList();
  }

  /// Görev ödülünü alır ve kullanıcıya jeton ekler
  static Future<bool> claimQuestReward(String questId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quests',
      where: 'id = ?',
      whereArgs: [questId],
    );

    if (maps.isEmpty) return false;

    final quest = Quest.fromMap(maps.first);
    if (quest.isClaimed || quest.currentProgress < quest.targetProgress) {
      return false; // Zaten alınmış veya tamamlanmamış
    }

    // Ödülü ver ve durumu güncelle
    await TokenService.addTokens(quest.rewardTokens);
    final updatedQuest = quest.copyWith(isClaimed: true, lastUpdated: DateTime.now());
    await _upsertQuest(updatedQuest);
    return true;
  }

  /// Test çözüldüğünde görev ilerlemelerini günceller
  static Future<void> onTestCompleted({
    required String difficulty,
    required int score,
    required int totalQuestions,
    required String category,
  }) async {
    // Önce görevlerin veritabanında var olduğundan emin olalım
    await initializeQuests();

    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('quests');
    final Map<String, Quest> quests = {
      for (var map in maps) map['id']: Quest.fromMap(map)
    };

    final now = DateTime.now();

    // 1. Solve 2 Quizzes (Daily)
    if (quests.containsKey(_dailySolve2Id)) {
      final q = quests[_dailySolve2Id]!;
      if (q.currentProgress < q.targetProgress) {
        await _upsertQuest(q.copyWith(
          currentProgress: q.currentProgress + 1,
          lastUpdated: now,
        ));
      }
    }

    // 2. Solve 7 Quizzes (Weekly)
    if (quests.containsKey(_weeklySolve7Id)) {
      final q = quests[_weeklySolve7Id]!;
      if (q.currentProgress < q.targetProgress) {
        await _upsertQuest(q.copyWith(
          currentProgress: q.currentProgress + 1,
          lastUpdated: now,
        ));
      }
    }

    // 3. Perfect Quiz (Daily)
    if (score == totalQuestions && quests.containsKey(_dailyPerfectId)) {
      final q = quests[_dailyPerfectId]!;
      if (q.currentProgress < q.targetProgress) {
        await _upsertQuest(q.copyWith(
          currentProgress: q.currentProgress + 1,
          lastUpdated: now,
        ));
      }
    }

    // 4. Perfect 3 Quizzes (Weekly)
    if (score == totalQuestions && quests.containsKey(_weeklyPerfect3Id)) {
      final q = quests[_weeklyPerfect3Id]!;
      if (q.currentProgress < q.targetProgress) {
        await _upsertQuest(q.copyWith(
          currentProgress: q.currentProgress + 1,
          lastUpdated: now,
        ));
      }
    }

    // 5. Hard/Impossible difficulty (Daily)
    if ((difficulty == 'Zor' || difficulty == 'Imkansız') && quests.containsKey(_dailyDifficultyZorId)) {
      final q = quests[_dailyDifficultyZorId]!;
      if (q.currentProgress < q.targetProgress) {
        await _upsertQuest(q.copyWith(
          currentProgress: q.currentProgress + 1,
          lastUpdated: now,
        ));
      }
    }

    // 6. Impossible difficulty (Weekly)
    if (difficulty == 'Imkansız' && quests.containsKey(_weeklyImpossibleId)) {
      final q = quests[_weeklyImpossibleId]!;
      if (q.currentProgress < q.targetProgress) {
        await _upsertQuest(q.copyWith(
          currentProgress: q.currentProgress + 1,
          lastUpdated: now,
        ));
      }
    }
  }

  /// Tarihin yılın kaçıncı haftası olduğunu döner
  static int _getWeekNumber(DateTime date) {
    // Basit bir haftalık indis hesaplama (1 Ocak'tan itibaren gün sayısı / 7)
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = date.difference(firstDayOfYear).inDays;
    return ((daysOffset + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }

  /// Görev başlıklarının yerelleştirilmiş metinlerini döner
  static String getQuestTitle(String id) {
    switch (id) {
      case _dailySolve2Id:
        return 'quests.solve_2_tests'.tr();
      case _dailyPerfectId:
        return 'quests.perfect_score'.tr();
      case _dailyDifficultyZorId:
        return 'quests.difficulty_zor'.tr();
      case _weeklySolve7Id:
        return 'quests.solve_7_tests'.tr();
      case _weeklyPerfect3Id:
        return 'quests.perfect_3_tests'.tr();
      case _weeklyImpossibleId:
        return 'quests.any_impossible'.tr();
      default:
        return 'Görev';
    }
  }
}
