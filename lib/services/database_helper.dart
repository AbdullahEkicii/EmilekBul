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
      version: 4,
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

  Future<void> deleteOldTests({int days = 7}) async {
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
      print('Cached quiz parse error: $e');
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
