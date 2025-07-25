class TestResult {
  final int? id;
  final String category;
  final String difficulty;
  final int score;
  final DateTime date;
  List<TestQuestionDetail> questions;

  TestResult({
    this.id,
    required this.category,
    required this.difficulty,
    required this.score,
    required this.date,
    this.questions = const [],
  });

  TestResult copy({
    int? id,
    String? category,
    String? difficulty,
    int? score,
    DateTime? date,
    List<TestQuestionDetail>? questions,
  }) => TestResult(
    id: id ?? this.id,
    category: category ?? this.category,
    difficulty: difficulty ?? this.difficulty,
    score: score ?? this.score,
    date: date ?? this.date,
    questions: questions ?? this.questions,
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'difficulty': difficulty,
      'score': score,
      'date': date.toIso8601String(),
    };
  }

  factory TestResult.fromMap(Map<String, dynamic> map) {
    return TestResult(
      id: map['id'],
      category: map['category'],
      difficulty: map['difficulty'],
      score: map['score'],
      date: DateTime.parse(map['date']),
    );
  }
}

class TestQuestionDetail {
  final int? id;
  final int testId;
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final List<String> options;

  TestQuestionDetail({
    this.id,
    required this.testId,
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.options,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'test_id': testId,
      'question': question,
      'user_answer': userAnswer,
      'correct_answer': correctAnswer,
      'options': options.join(','),
    };
  }

  factory TestQuestionDetail.fromMap(Map<String, dynamic> map) {
    return TestQuestionDetail(
      id: map['id'],
      testId: map['test_id'],
      question: map['question'],
      userAnswer: map['user_answer'],
      correctAnswer: map['correct_answer'],
      options: (map['options'] as String).split(','),
    );
  }
}
