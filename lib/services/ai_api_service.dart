import 'package:flutter/foundation.dart';
import '../models/question.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'dart:convert';

import '../services/database_helper.dart';
import '../utils/app_utils.dart';

class AiApiService {
  final List<String> _modelList = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
    'gemini-3-flash-preview',
    'gemini-3-flash',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash-001',
    'gemini-2.0-flash-lite-001',
  ];
  final String _apiKey = dotenv.env['API_KEY']!;
  Future<GenerateContentResponse> _generateContentWithFallback(
      String prompt) async {
    final content = Content.text(prompt);
    for (final modelName in _modelList) {
      final model = GenerativeModel(model: modelName, apiKey: _apiKey);
      try {
        debugPrint('🧠 Deneniyor: $modelName');
        final response = await model.generateContent([content]);
        debugPrint('✅ Başarılı model: $modelName');
        return response;
      } catch (e) {
        debugPrint('⚠️ $modelName modeli hata verdi: $e');
        if (!e.toString().contains('429') &&
            !e.toString().contains('quota') &&
            !e.toString().contains('RESOURCE_EXHAUSTED') &&
            !e.toString().contains('404') &&
            !e.toString().contains('503')) {
          rethrow; // Beklenmeyen hata varsa dur
        }
      }
    }
    throw Exception(
        'Tüm modellerle istek başarısız oldu. Limitler dolmuş olabilir.');
  }

  Future<List<Question>> fetchMultilingualQuestions({
    required String category,
    required String difficulty,
    required List<String> languageCodes,
    int count = 5,
  }) async {
    final uniqueLangs =
        languageCodes.where((l) => l.trim().isNotEmpty).toSet().toList();
    if (uniqueLangs.isEmpty) {
      uniqueLangs.add('tr');
    }

    if (uniqueLangs.length == 1) {
      return fetchQuestions(
        category: category,
        difficulty: difficulty,
        languageCode: uniqueLangs.first,
        count: count,
      );
    }

    try {
      final hasInternet = await AppUtils.hasInternetConnection();
      if (!hasInternet) {
        throw Exception('no_internet');
      }

      final randomSeed = DateTime.now().millisecondsSinceEpoch;
      // Sadece bu kategoride son 14 gün içinde çözülen en fazla 15 testin sorularını çek (Token tasarrufu & tekrarı önleme)
      final previousQuestionRoots = await DatabaseHelper.instance
          .getRecentQuestionRootsForCategory(category, testLimit: 15, days: 14);

      final prompt = _getMultilingualInstruction(
        languageCodes: uniqueLangs,
        category: category,
        difficulty: difficulty,
        count: count,
        previousQuestionRoots: previousQuestionRoots,
        randomSeed: randomSeed,
      );

      final response = await _generateContentWithFallback(prompt);
      final text = response.text;
      final jsonStart = text?.indexOf('[') ?? -1;
      final jsonEnd = text?.lastIndexOf(']') ?? -1;
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('ai_service.errors.format_error');
      }
      final jsonString = text!.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => Question.fromJson(e)).toList();
    } catch (e, s) {
      debugPrint('AI API MULTILINGUAL HATASI: $e\n$s');
      if (e.toString().contains('ai_service.errors')) {
        rethrow;
      }
      throw Exception('ai_service.errors.general_error');
    }
  }

  Future<List<Question>> fetchQuestions({
    required String category,
    required String difficulty,
    required String languageCode,
    int count = 5,
  }) async {
    try {
      final hasInternet = await AppUtils.hasInternetConnection();
      if (!hasInternet) {
        throw Exception('no_internet');
      }

      final randomSeed = DateTime.now().millisecondsSinceEpoch;
      // Sadece bu kategoride son 14 gün içinde çözülen en fazla 15 testin sorularını çek (Token tasarrufu)
      final previousQuestionRoots = await DatabaseHelper.instance
          .getRecentQuestionRootsForCategory(category, testLimit: 15, days: 14);

      final prompt = _getSystemInstruction(
        languageCode: languageCode,
        category: category,
        difficulty: difficulty,
        count: count,
        previousQuestionRoots: previousQuestionRoots,
        randomSeed: randomSeed,
      );

      final response = await _generateContentWithFallback(prompt);
      final text = response.text;
      final jsonStart = text?.indexOf('[') ?? -1;
      final jsonEnd = text?.lastIndexOf(']') ?? -1;
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('ai_service.errors.format_error');
      }
      final jsonString = text!.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => Question.fromJson(e)).toList();
    } catch (e, s) {
      debugPrint('AI API HATASI: $e\n$s');
      if (e.toString().contains('ai_service.errors')) {
        rethrow;
      }
      throw Exception('ai_service.errors.general_error');
    }
  }

  static const Map<String, String> _languageNames = {
    'tr': 'Turkish (Türkçe)',
    'en': 'English',
    'de': 'German (Deutsch)',
    'fr': 'French (Français)',
    'es': 'Spanish (Español)',
    'ar': 'Arabic (العربية)',
    'ru': 'Russian (Русский)',
    'it': 'Italian (Italiano)',
    'pt': 'Portuguese (Português)',
    'zh': 'Chinese (中文)',
    'ja': 'Japanese (日本語)',
    'ko': 'Korean (한국어)',
    'hi': 'Hindi (हिन्दी)',
    'nl': 'Dutch (Nederlands)',
    'pl': 'Polish (Polski)',
    'uk': 'Ukrainian (Українська)',
    'vi': 'Vietnamese (Tiếng Việt)',
    'th': 'Thai (ไทย)',
    'id': 'Indonesian (Bahasa Indonesia)',
    'cs': 'Czech (Čeština)',
    'da': 'Danish (Dansk)',
    'fi': 'Finnish (Suomi)',
    'hu': 'Hungarian (Magyar)',
    'ro': 'Romanian (Română)',
    'sv': 'Swedish (Svenska)',
    'el': 'Greek (Ελληνικά)',
  };

  static const Map<String, String> _categoryMap = {
    'Genel Kültür': 'General Culture',
    'Yemek Kültürü': 'Food Culture',
    'Coğrafya': 'Geography',
    'Futbol': 'Football',
    'Dini': 'Religious & World Beliefs',
    'Bilim': 'Science',
    'Sinema ve Dizi': 'Cinema & Series',
    'Tarih': 'History',
    'Magazin': 'Celebrity & Pop Culture',
    'Müzik': 'Music',
    'Uzay ve Evren': 'Space & Universe',
    'Mitoloji ve Efsaneler': 'Mythology & Legends',
    'Antik Uygarlıklar': 'Ancient Civilizations & Archaeology',
    'Video Oyunları & Espor': 'Video Games & Esports',
    'Dünya Mutfakları': 'World Cuisine & Gourmet',
    'Dünya Harikaları & Doğa': 'World Wonders & Nature',
    'Çizgi Roman & Anime': 'Comics, Manga & Anime',
    'Felsefe & Düşünce': 'Philosophy & History of Thought',
    'Yapay Zeka & Gelecek': 'Artificial Intelligence & Future Tech',
    'Doğa ve Vahşi Yaşam': 'Wildlife & Nature',
    'Klasik Sanat & Mimari': 'Classical Art & Architecture',
    'Edebiyat & Başyapıtlar': 'World Literature & Masterpieces',
  };

  String _getMultilingualInstruction({
    required List<String> languageCodes,
    required String category,
    required String difficulty,
    required int count,
    required Set<String> previousQuestionRoots,
    required int randomSeed,
  }) {
    final langListStr = languageCodes
        .map((code) => "$code (${_languageNames[code] ?? code})")
        .join(', ');

    final previousTextBlock = previousQuestionRoots.isNotEmpty
        ? "Previously used question roots (DO NOT duplicate these):\n${previousQuestionRoots.map((q) => "- $q").join("\n")}"
        : "No previous questions recorded for this category and difficulty yet.";

    return '''You are a multilingual trivia quiz AI. Generate $count original trivia questions for a synchronized 1v1 live multiplayer duel.
Both players are playing at the exact same time against each other, but each player speaks a different language.

Parameters:
- Category: '$category'
- Difficulty: '$difficulty'
- Languages needed: $langListStr

Rules:
1. Exactly 4 options per question.
2. The options at index 0, 1, 2, 3 in each language MUST be exact translations/equivalents of each other so both players have matching choices.
3. The 'correctIndex' (0, 1, 2, or 3) MUST be identical and correct across all languages.
4. Language & Quality: The questions and choices in each language MUST be grammatically flawless, natural, and clear for native speakers.
5. Focus on fair, universally verifiable knowledge suitable for global players.
6. UNIQUENESS:
   - $previousTextBlock

OUTPUT STRICTLY AND ONLY IN VALID JSON FORMAT (no preamble, no markdown tags other than standard json, no explanations):
[
  {
    "question": "Question in ${languageCodes.first}",
    "options": ["Option 0", "Option 1", "Option 2", "Option 3"],
    "correctIndex": 0,
    "translations": {
${languageCodes.map((code) => '      "$code": {\n        "question": "Question in $code",\n        "options": ["Opt0 in $code", "Opt1 in $code", "Opt2 in $code", "Opt3 in $code"]\n      }').join(',\n')}
    }
  }
]
Seed: $randomSeed
''';
  }

  String _getSystemInstruction({
    required String languageCode,
    required String category,
    required String difficulty,
    required int count,
    required Set<String> previousQuestionRoots,
    required int randomSeed,
  }) {
    final targetLangName = _languageNames[languageCode] ?? 'English';
    final promptCategory =
        languageCode == 'tr' ? category : (_categoryMap[category] ?? category);

    final previousTextBlock = previousQuestionRoots.isNotEmpty
        ? "Previously used question roots (DO NOT duplicate these):\n${previousQuestionRoots.map((q) => "- $q").join("\n")}"
        : "No previous questions recorded for this category and difficulty yet.";

    return '''You are an expert trivia quiz AI. Generate $count unique and original trivia questions.

Parameters:
- Target Language: $targetLangName (ISO Code: $languageCode)
- Category: '$promptCategory'
- Difficulty: '$difficulty' (Easy: Basic common knowledge, Medium: Doable/general knowledge, Hard: Detailed knowledge, Impossible: Very technical/niche knowledge)

Critical Rules:
1. LANGUAGE & NATURAL PHRASING:
   - All questions, choices, and text MUST be written 100% in $targetLangName with proper native grammar, natural phrasing, accurate punctuation, and cultural clarity.
2. QUESTION STRUCTURE:
   - Exactly 4 options per question with exactly 1 unambiguously correct option.
   - Questions and options should be concise, clear, and proportional to the difficulty.
   - The 'correctIndex' MUST be an integer between 0 and 3 matching the correct option.
3. GLOBAL FAIRNESS:
   - If the category relates to History, Geography, or General Culture, focus on globally known, verifiable facts rather than ultra-local obscure trivia.
4. UNIQUENESS:
   - $previousTextBlock

OUTPUT STRICTLY AND ONLY IN VALID JSON FORMAT (no preamble, no markdown tags other than standard json, no explanations):
[
  {
    "question": "Question text in $targetLangName",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0
  }
]
Seed: $randomSeed
''';
  }
}
