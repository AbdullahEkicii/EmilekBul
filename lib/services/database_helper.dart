import 'package:emilekbul/models/test_result.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
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

    // Önce tüm testleri al
    final List<Map<String, dynamic>> tests = await db.query('tests');

    Map<String, Map<String, int>> stats = {};

    for (var test in tests) {
      final category = test['category'] as String;
      final testId = test['id'] as int;

      // Her test için soruları al
      final List<Map<String, dynamic>> questions = await db.query(
        'test_questions',
        where: 'test_id = ?',
        whereArgs: [testId],
      );

      // Kategori için stats oluştur
      if (!stats.containsKey(category)) {
        stats[category] = {'correct': 0, 'wrong': 0};
      }

      // Her soru için doğru/yanlış sayısını hesapla
      for (var question in questions) {
        final userAnswer = question['user_answer'] as String;
        final correctAnswer = question['correct_answer'] as String;

        if (userAnswer == correctAnswer) {
          stats[category]!['correct'] = stats[category]!['correct']! + 1;
        } else {
          stats[category]!['wrong'] = stats[category]!['wrong']! + 1;
        }
      }
    }

    return stats;
  }

  Future<Map<String, Map<String, int>>> getCategoryStats() async {
    // Bu metod test_results tablosunu kullanıyor ama o tablo yok
    // Yukarıdaki getCategoryStatsFromTests metodunu kullanın
    return getCategoryStatsFromTests();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
