import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:emilekbul/models/test_result.dart';
import 'package:emilekbul/models/question.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('quiz.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE logins (
  date TEXT PRIMARY KEY
)
''');
    }
    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE cached_quizzes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  language_code TEXT NOT NULL,
  questions_json TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
    }
    if (oldVersion < 4) {
      await db.execute('''
CREATE TABLE quests (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  target_progress INTEGER NOT NULL,
  current_progress INTEGER NOT NULL,
  reward_tokens INTEGER NOT NULL,
  is_claimed INTEGER NOT NULL,
  last_updated TEXT NOT NULL
)
''');
      await db.execute('''
CREATE TABLE achievements (
  id TEXT PRIMARY KEY,
  unlocked_at TEXT NOT NULL
)
''');
    }
    if (oldVersion < 5) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS cached_questions (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  language_code TEXT NOT NULL,
  question_root TEXT NOT NULL,
  question_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''');
      await db.execute('''
CREATE TABLE IF NOT EXISTS seen_questions (
  question_id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  answered_at INTEGER NOT NULL
)
''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE tests (
  id $idType,
  category $textType,
  difficulty $textType,
  score $integerType,
  date $textType
)
''');

    await db.execute('''
CREATE TABLE test_questions (
  id $idType,
  test_id INTEGER NOT NULL,
  question $textType,
  user_answer $textType,
  correct_answer $textType,
  options $textType,
  FOREIGN KEY (test_id) REFERENCES tests (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE logins (
  date TEXT PRIMARY KEY
)
''');

    await db.execute('''
CREATE TABLE cached_quizzes (
  id $idType,
  category $textType,
  difficulty $textType,
  language_code $textType,
  questions_json $textType,
  created_at $textType
)
''');

    await db.execute('''
CREATE TABLE quests (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  target_progress INTEGER NOT NULL,
  current_progress INTEGER NOT NULL,
  reward_tokens INTEGER NOT NULL,
  is_claimed INTEGER NOT NULL,
  last_updated TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE achievements (
  id TEXT PRIMARY KEY,
  unlocked_at TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE cached_questions (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  language_code TEXT NOT NULL,
  question_root TEXT NOT NULL,
  question_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE seen_questions (
  question_id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  answered_at INTEGER NOT NULL
)
''');
  }

  Future<TestResult> createTest(TestResult test) async {
    final db = await instance.database;
    final id = await db.insert('tests', test.toMap());

    for (var question in test.questions) {
      final questionWithTestId = TestQuestionDetail(
        testId: id,
        question: question.question,
        userAnswer: question.userAnswer,
        correctAnswer: question.correctAnswer,
        options: question.options,
      );
      await db.insert('test_questions', questionWithTestId.toMap());
    }
    return test.copy(id: id);
  }

  Future<List<TestResult>> getAllTests() async {
    final db = await instance.database;
    final maps = await db.query('tests', orderBy: 'date DESC');

    if (maps.isEmpty) {
      return [];
    }

    List<TestResult> tests = [];
    for (var map in maps) {
      final test = TestResult.fromMap(map);
      final questions = await getTestQuestions(test.id!);
      test.questions = questions;
      tests.add(test);
    }
    return tests;
  }

  Future<List<TestQuestionDetail>> getTestQuestions(int testId) async {
    final db = await instance.database;
    final maps = await db.query(
      'test_questions',
      where: 'test_id = ?',
      whereArgs: [testId],
    );

    if (maps.isEmpty) {
      return [];
    }

    return maps.map((map) => TestQuestionDetail.fromMap(map)).toList();
  }

  /// Belirli bir kategoride son X günde çözülen en fazla N testin soru köklerini getirir (Token optimizasyonu)
  Future<Set<String>> getRecentQuestionRootsForCategory(
    String category, {
    int testLimit = 15,
    int days = 14,
  }) async {
    final db = await instance.database;
    final thresholdDate =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final testMaps = await db.query(
      'tests',
      columns: ['id'],
      where: 'category = ? AND date >= ?',
      whereArgs: [category, thresholdDate],
      orderBy: 'date DESC',
      limit: testLimit,
    );

    if (testMaps.isEmpty) {
      return <String>{};
    }

    final testIds = testMaps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(testIds.length, '?').join(',');

    final questionMaps = await db.rawQuery(
      'SELECT question FROM test_questions WHERE test_id IN ($placeholders)',
      testIds,
    );

    final Set<String> questionRoots = {};
    for (final row in questionMaps) {
      final q = (row['question'] as String?)?.trim();
      if (q != null && q.isNotEmpty) {
        questionRoots.add(q);
      }
    }
    return questionRoots;
  }

  Future<void> deleteOldTests({int days = 14}) async {
    final db = await instance.database;

    final now = DateTime.now();
    final thresholdDate = now.subtract(Duration(days: days));
    final thresholdString = thresholdDate.toIso8601String();

    // Veritabanında tarih formatı ISO-8601 string (örnek: 2024-07-21T15:00:00)
    await db.delete('tests', where: 'date < ?', whereArgs: [thresholdString]);
  }

  Future<Map<String, Map<String, int>>> getCategoryStatsFromTests() async {
    final db = await database;

    // Tek bir sorgu ile tüm verileri JOIN yaparak çekiyoruz (N+1 problemini çözer)
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT t.category, q.user_answer, q.correct_answer 
      FROM tests t
      JOIN test_questions q ON t.id = q.test_id
    ''');

    Map<String, Map<String, int>> stats = {};

    for (var row in results) {
      final category = row['category'] as String;
      final userAnswer = row['user_answer'] as String;
      final correctAnswer = row['correct_answer'] as String;

      if (!stats.containsKey(category)) {
        stats[category] = {'correct': 0, 'wrong': 0};
      }

      if (userAnswer == correctAnswer) {
        stats[category]!['correct'] = stats[category]!['correct']! + 1;
      } else {
        stats[category]!['wrong'] = stats[category]!['wrong']! + 1;
      }
    }

    return stats;
  }

  Future<Map<String, Map<String, int>>> getCategoryStats() async {
    // Bu metod test_results tablosunu kullanıyor ama o tablo yok
    // Yukarıdaki getCategoryStatsFromTests metodunu kullanın
    return getCategoryStatsFromTests();
  }

  Future<bool> recordLoginAndCheckConsecutive() async {
    final db = await instance.database;
    final now = DateTime.now();
    final today =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Bugünü kontrol et
    final todayMaps = await db.query(
      'logins',
      where: 'date = ?',
      whereArgs: [today],
    );

    if (todayMaps.isNotEmpty) {
      // Zaten bugün kaydedilmiş
      return false;
    }

    // Bugünü kaydet
    await db.insert('logins', {'date': today});

    // Dünü kontrol et
    final yesterdayDate = now.subtract(const Duration(days: 1));
    final yesterday =
        "${yesterdayDate.year}-${yesterdayDate.month.toString().padLeft(2, '0')}-${yesterdayDate.day.toString().padLeft(2, '0')}";

    final yesterdayMaps = await db.query(
      'logins',
      where: 'date = ?',
      whereArgs: [yesterday],
    );

    // Dün de giriş yapılmışsa true döndür
    return yesterdayMaps.isNotEmpty;
  }

  // Jeton/Soru Önbelleğe Alma Metotları

  Future<void> saveCachedQuiz(
      String category, String difficulty, String languageCode, String questionsJson) async {
    final db = await instance.database;
    await db.insert('cached_quizzes', {
      'category': category,
      'difficulty': difficulty,
      'language_code': languageCode,
      'questions_json': questionsJson,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Question>?> getCachedQuiz(
      String category, String difficulty, String languageCode) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_quizzes',
      where: 'category = ? AND difficulty = ? AND language_code = ?',
      whereArgs: [category, difficulty, languageCode],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    final cached = maps.first;
    final int id = cached['id'] as int;
    final String jsonString = cached['questions_json'] as String;

    // Önbellekten okuduktan sonra bu kaydı silelim ki tekrar kullanılmasın
    await db.delete('cached_quizzes', where: 'id = ?', whereArgs: [id]);

    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => Question.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Cached quiz parse error: $e');
      return null;
    }
  }

  Future<int> getCachedQuizCount(
      String category, String difficulty, String languageCode) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM cached_quizzes WHERE category = ? AND difficulty = ? AND language_code = ?',
      [category, difficulty, languageCode],
    );
    if (result.isEmpty) return 0;
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==========================================
  // HİBRİT SORU HAVUZU & ÖNBELLEK YÖNETİMİ
  // ==========================================

  /// Soruları yerel SQLite havuzuna kaydeder
  Future<void> saveCachedQuestions(
    List<Question> questions, {
    required String category,
    required String difficulty,
    required String languageCode,
  }) async {
    final db = await instance.database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final q in questions) {
      final qRoot = q.question.toLowerCase().replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]'), '').trim();
      final qId = 'q_${category.hashCode.abs()}_${qRoot.hashCode.abs()}';

      batch.insert(
        'cached_questions',
        {
          'id': qId,
          'category': category,
          'difficulty': difficulty,
          'language_code': languageCode,
          'question_root': qRoot,
          'question_json': jsonEncode(q.toJson()),
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Kullanıcının daha önce görmediği havuz sorularını getirir
  Future<List<Question>> getUnseenCachedQuestions({
    required String category,
    required String difficulty,
    required String languageCode,
    required int count,
  }) async {
    final db = await instance.database;
    final query = '''
      SELECT cq.id, cq.question_json
      FROM cached_questions cq
      LEFT JOIN seen_questions sq ON cq.id = sq.question_id
      WHERE cq.category = ? AND cq.difficulty = ? AND cq.language_code = ? AND sq.question_id IS NULL
      ORDER BY RANDOM()
      LIMIT ?
    ''';

    final rows = await db.rawQuery(query, [category, difficulty, languageCode, count]);
    if (rows.isEmpty) return [];

    List<Question> questions = [];
    List<String> seenIds = [];

    for (final row in rows) {
      final jsonStr = row['question_json'] as String;
      final qId = row['id'] as String;
      try {
        final qMap = jsonDecode(jsonStr);
        questions.add(Question.fromJson(qMap));
        seenIds.add(qId);
      } catch (_) {}
    }

    if (seenIds.isNotEmpty) {
      await markQuestionsAsSeen(seenIds, category: category);
    }

    return questions;
  }

  /// Görülmemiş kalmadığında ve AI ulaşılamadığında tüm önbellekteki soruları döner
  Future<List<Question>> getRecycledCachedQuestions({
    required String category,
    required String difficulty,
    required String languageCode,
    required int count,
  }) async {
    final db = await instance.database;
    final query = '''
      SELECT id, question_json
      FROM cached_questions
      WHERE category = ? AND difficulty = ? AND language_code = ?
      ORDER BY RANDOM()
      LIMIT ?
    ''';
    final rows = await db.rawQuery(query, [category, difficulty, languageCode, count]);
    if (rows.isEmpty) return [];

    List<Question> questions = [];
    for (final row in rows) {
      try {
        questions.add(Question.fromJson(jsonDecode(row['question_json'] as String)));
      } catch (_) {}
    }
    return questions;
  }

  /// Soruları kullanıcının gördüğü olarak işaretler
  Future<void> markQuestionsAsSeen(List<String> questionIds, {String category = ''}) async {
    final db = await instance.database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final id in questionIds) {
      batch.insert(
        'seen_questions',
        {
          'question_id': id,
          'category': category,
          'answered_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Belirli bir kategori için görülmemiş havuz soru sayısını döner
  Future<int> getUnseenCachedQuestionsCount(String category, String difficulty, String languageCode) async {
    final db = await instance.database;
    final query = '''
      SELECT COUNT(*) as count
      FROM cached_questions cq
      LEFT JOIN seen_questions sq ON cq.id = sq.question_id
      WHERE cq.category = ? AND cq.difficulty = ? AND cq.language_code = ? AND sq.question_id IS NULL
    ''';
    final result = await db.rawQuery(query, [category, difficulty, languageCode]);
    if (result.isEmpty) return 0;
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==========================================
  // ARALIKLI TEKRAR (SPACED REPETITION)
  // ==========================================

  /// Kullanıcının en az 4-5 test önce yanlış cevapladığı soruları çeker ve şıklarını karıştırarak döner
  Future<List<Question>> getSpacedRepetitionQuestions(String category, {int limit = 1, int minTestsAgo = 4}) async {
    final db = await instance.database;

    // En son çözülen testleri hariç tut (aradan en az 4-5 test geçmiş olsun)
    final recentTests = await db.query(
      'tests',
      columns: ['id'],
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'id DESC',
      limit: minTestsAgo,
    );
    final excludedTestIds = recentTests.map((t) => t['id'] as int).toList();

    String whereClause = 't.category = ? AND tq.user_answer != tq.correct_answer';
    List<dynamic> whereArgs = [category];

    if (excludedTestIds.isNotEmpty) {
      whereClause += ' AND t.id NOT IN (${List.filled(excludedTestIds.length, '?').join(',')})';
      whereArgs.addAll(excludedTestIds);
    }

    final query = '''
      SELECT tq.question, tq.correct_answer, tq.options
      FROM test_questions tq
      INNER JOIN tests t ON t.id = tq.test_id
      WHERE $whereClause
      ORDER BY tq.id DESC
      LIMIT 25
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    if (rows.isEmpty) return [];

    final random = Random();
    final shuffledRows = List<Map<String, dynamic>>.from(rows)..shuffle(random);
    final selectedRows = shuffledRows.take(limit);

    List<Question> spacedQuestions = [];
    for (final row in selectedRows) {
      final questionText = row['question'] as String;
      final correctAnswer = row['correct_answer'] as String;
      final optionsRaw = row['options'];
      List<String> options = [];
      if (optionsRaw is String) {
        try {
          final decoded = jsonDecode(optionsRaw);
          if (decoded is List) {
            options = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          options = optionsRaw.split('||').map((e) => e.trim()).toList();
        }
      }

      if (options.length >= 4 && options.contains(correctAnswer)) {
        options.shuffle(random);
        final newCorrectIndex = options.indexOf(correctAnswer);
        spacedQuestions.add(Question(
          question: questionText,
          options: options,
          correctIndex: newCorrectIndex,
        ));
      }
    }
    return spacedQuestions;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
