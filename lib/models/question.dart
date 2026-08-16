class Question {
  final String question;
  final List<String> options;
  final int correctIndex;
  final Map<String, dynamic>? translations;

  Question({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.translations,
  });

  // API'den veya veritabanından gelen veriyi modele dönüştürmek için factory
  factory Question.fromJson(Map<dynamic, dynamic> json) {
    Map<String, dynamic>? parsedTranslations;
    if (json['translations'] is Map) {
      parsedTranslations = Map<String, dynamic>.from(json['translations'] as Map);
    }

    return Question(
      question: json['question']?.toString() ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      translations: parsedTranslations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      if (translations != null) 'translations': translations,
    };
  }

  /// Aktif dile göre soru metnini getirir, yoksa varsayılan metni döner
  String getLocalizedQuestion(String languageCode) {
    if (translations != null && translations!.containsKey(languageCode)) {
      final t = translations![languageCode];
      if (t is Map && t['question'] != null && t['question'].toString().trim().isNotEmpty) {
        return t['question'].toString();
      }
    }
    return question;
  }

  /// Aktif dile göre şıkları getirir, yoksa varsayılan şıkları döner
  List<String> getLocalizedOptions(String languageCode) {
    if (translations != null && translations!.containsKey(languageCode)) {
      final t = translations![languageCode];
      if (t is Map && t['options'] is List) {
        final list = (t['options'] as List).map((e) => e.toString()).toList();
        if (list.length == options.length && list.isNotEmpty) {
          return list;
        }
      }
    }
    return options;
  }
}

