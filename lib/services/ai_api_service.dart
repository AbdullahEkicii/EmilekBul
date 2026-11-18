import 'error_reporter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/question.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'dart:async';
import 'dart:convert';

import '../services/database_helper.dart';
import '../services/remote_flags.dart';
import '../utils/app_utils.dart';
import '../constants/category_taxonomy.dart';

class AiApiService {
  // Doğrulanmış hızlı Gemini modelleri (bütçe içinde gereksiz 404 gecikmesini önlemek için)
  final List<String> _modelList = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
  ];
  String? get _apiKey => dotenv.maybeGet('API_KEY');
  // Model başına zaman aşımı ve tüm denemeler için toplam süre bütçesi
  static const Duration _perModelTimeout = Duration(seconds: 7);
  static const Duration _totalBudget = Duration(seconds: 12);
  // Soru/şık uzunluk sınırları (prompt + istemci tarafı doğrulama aynı değerleri kullanır)
  static const int _maxQuestionChars = 160;
  static const int _maxOptionChars = 50;

  Future<String?> _generateViaProxy(
    String proxyUrl,
    String prompt, {
    required int maxOutputTokens,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $idToken';
      }
      try {
        final appCheckToken = await FirebaseAppCheck.instance.getToken();
        if (appCheckToken != null && appCheckToken.isNotEmpty) {
          headers['X-Firebase-AppCheck'] = appCheckToken;
        }
      } catch (_) {}

      final res = await http
          .post(
            Uri.parse(proxyUrl),
            headers: headers,
            body: jsonEncode({
              'prompt': prompt,
              'maxOutputTokens': maxOutputTokens,
              'responseMimeType': 'application/json',
            }),
          )
          .timeout(_totalBudget);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['text'] != null) {
          return decoded['text'].toString();
        }
        return res.body;
      }
      debugPrint('⚠️ AI proxy HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('⚠️ AI proxy hata verdi: $e');
    }
    return null;
  }

  Future<String?> _generateContentWithFallback(
    String prompt, {
    int maxOutputTokens = 4096,
  }) async {
    final proxyUrl = RemoteFlags.aiProxyUrl;
    if (proxyUrl.isNotEmpty) {
      final proxyText = await _generateViaProxy(
        proxyUrl,
        prompt,
        maxOutputTokens: maxOutputTokens,
      );
      if (proxyText != null && proxyText.isNotEmpty) {
        return proxyText;
      }
    }

    final apiKey = _apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      ErrorReporter.record(Exception('ai_missing_api_key'), null, reason: 'ai_no_key_or_proxy');
      throw Exception('ai_service.errors.general_error');
    }

    final content = Content.text(prompt);
    final budgetWatch = Stopwatch()..start();
    for (final modelName in _modelList) {
      // Toplam bütçe aşıldıysa kalan modelleri deneme (ilk deneme her zaman yapılır)
      if (budgetWatch.elapsed >= _totalBudget) {
        debugPrint('⏱️ AI toplam süre bütçesi aşıldı, model denemesi durduruldu.');
        break;
      }
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.9,
          // Düşünen (thinking) modellerde düşünme token'ları da bu limite dahildir; cömert tut.
          maxOutputTokens: maxOutputTokens,
          responseMimeType: 'application/json',
        ),
      );
      try {
        debugPrint('🧠 Deneniyor: $modelName');
        final remaining = _totalBudget - budgetWatch.elapsed;
        final timeout = remaining < _perModelTimeout && remaining > Duration.zero
            ? remaining
            : _perModelTimeout;
        final response =
            await model.generateContent([content]).timeout(timeout);
        debugPrint('✅ Başarılı model: $modelName');
        return response.text;
      } catch (e) {
        debugPrint('⚠️ $modelName modeli hata verdi: $e');
        // Tüm hata türlerinde bir sonraki yedek modele geç
        continue;
      }
    }
    ErrorReporter.record(Exception('ai_all_models_failed'), null, reason: 'ai_fallback_exhausted');
    throw Exception(
        'Tüm modellerle istek başarısız oldu. Limitler dolmuş veya internet bağlantısı kesilmiş olabilir.');
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

      final response = await _generateContentWithFallback(
        prompt,
        maxOutputTokens: 2048 + count * 700 * uniqueLangs.length,
      );
      return _parseQuestions(response);
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

      final response = await _generateContentWithFallback(
        prompt,
        maxOutputTokens: 2048 + count * 700,
      );
      return _parseQuestions(response);
    } catch (e, s) {
      debugPrint('AI API HATASI: $e\n$s');
      if (e.toString().contains('ai_service.errors')) {
        rethrow;
      }
      throw Exception('ai_service.errors.general_error');
    }
  }

  List<Question> _parseQuestions(String? text) {
    final jsonStart = text?.indexOf('[') ?? -1;
    final jsonEnd = text?.lastIndexOf(']') ?? -1;
    if (jsonStart == -1 || jsonEnd == -1) {
      throw Exception('ai_service.errors.format_error');
    }
    final List<dynamic> list = jsonDecode(text!.substring(jsonStart, jsonEnd + 1));
    final all = list.map((e) => Question.fromJson(e)).toList();
    // Aşırı uzun soru/şık üretenleri ele; hepsi elenirse yine de hepsini döndür (boş test olmasın)
    final compact = all.where(_isCompact).toList();
    if (compact.length != all.length) {
      debugPrint('✂️ ${all.length - compact.length} uzun soru elendi');
    }
    return compact.isNotEmpty ? compact : all;
  }

  /// Havuz/önbellekten okunan sorulara da aynı uzunluk filtresini uygulamak için herkese açık.
  static bool isCompactQuestion(Question q) => _isCompactStatic(q);

  bool _isCompact(Question q) => _isCompactStatic(q);

  static bool _isCompactStatic(Question q) {
    if (q.options.length != 4 || q.correctIndex < 0 || q.correctIndex > 3) {
      return false;
    }
    bool fits(String question, List<String> options) =>
        question.length <= _maxQuestionChars &&
        options.every((o) => o.length <= _maxOptionChars);
    if (!fits(q.question, q.options)) return false;
    for (final entry in (q.translations ?? const <String, dynamic>{}).entries) {
      final t = entry.value;
      if (t is Map &&
          !fits(t['question']?.toString() ?? '',
              (t['options'] as List?)?.map((e) => e.toString()).toList() ?? const [])) {
        return false;
      }
    }
    return true;
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

    final subTopic = CategoryTaxonomy.getRandomSubTopic(category);
    final questionAngle = CategoryTaxonomy.getRandomQuestionAngle();

    final previousTextBlock = previousQuestionRoots.isNotEmpty
        ? "Previously used question roots (DO NOT duplicate these topics):\n${previousQuestionRoots.take(20).map((q) => "- $q").join("\n")}"
        : "No previous questions recorded for this category and difficulty yet.";

    return '''You are a multilingual trivia quiz AI. Generate $count original trivia questions for a synchronized 1v1 live multiplayer duel.
Both players are playing at the exact same time against each other, but each player speaks a different language.

Parameters:
- Category: '$category'
- Sub-Topic Focus: '$subTopic'
- Question Angle / Perspective: '$questionAngle'
- Difficulty: '$difficulty'
- Languages needed: $langListStr

Rules:
1. Exactly 4 options per question.
   LENGTH LIMITS (hard): the question text MUST be a single sentence of at most $_maxQuestionChars characters; each option MUST be at most $_maxOptionChars characters (a name, term, date or short phrase - never a sentence or list). Do NOT embed long scenarios, multi-part lists or numbered statements in the question; if the angle suggests it, compress it into one short line.
2. The options at index 0, 1, 2, 3 in each language MUST be exact translations/equivalents of each other so both players have matching choices.
3. The 'correctIndex' (0, 1, 2, or 3) MUST be identical and correct across all languages.
4. Language & Quality: The questions and choices in each language MUST be grammatically flawless, natural, and clear for native speakers.
5. Focus on fair, universally verifiable knowledge suitable for global players within '$subTopic'.
6. UNIQUENESS & DIVERSITY:
   - Deeply explore the sub-topic '$subTopic' using the angle '$questionAngle'.
   - Avoid generic, overused trivia tropes.
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

    final subTopic = CategoryTaxonomy.getRandomSubTopic(category);
    final questionAngle = CategoryTaxonomy.getRandomQuestionAngle();

    final previousTextBlock = previousQuestionRoots.isNotEmpty
        ? "Previously used question roots (DO NOT duplicate these topics):\n${previousQuestionRoots.take(20).map((q) => "- $q").join("\n")}"
        : "No previous questions recorded for this category and difficulty yet.";

    return '''You are an expert trivia quiz AI. Generate $count unique and original trivia questions.

Parameters:
- Target Language: $targetLangName (ISO Code: $languageCode)
- Category: '$promptCategory'
- Sub-Topic Focus: '$subTopic'
- Question Angle / Perspective: '$questionAngle'
- Difficulty: '$difficulty' (Easy: Basic common knowledge, Medium: Doable/general knowledge, Hard: Detailed knowledge, Impossible: Very technical/niche knowledge)

Critical Rules:
1. LANGUAGE & NATURAL PHRASING:
   - All questions, choices, and text MUST be written 100% in $targetLangName with proper native grammar, natural phrasing, accurate punctuation, and cultural clarity.
2. QUESTION STRUCTURE:
   - Exactly 4 options per question with exactly 1 unambiguously correct option.
   - Questions and options should be concise, clear, and proportional to the difficulty.
   - LENGTH LIMITS (hard): the question text MUST be a single sentence of at most $_maxQuestionChars characters; each option MUST be at most $_maxOptionChars characters (a name, term, date or short phrase - never a sentence or list). Do NOT embed long scenarios, multi-part lists or numbered statements in the question; if the angle suggests it, compress it into one short line.
   - The 'correctIndex' MUST be an integer between 0 and 3 matching the correct option.
3. UNIQUENESS & DIVERSITY:
   - Specifically focus on the sub-topic '$subTopic' with the perspective '$questionAngle'.
   - Avoid generic, overused clichés. Create high-engagement, fresh trivia.
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
