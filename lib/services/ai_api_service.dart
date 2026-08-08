import 'package:flutter/foundation.dart';
import '../models/question.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'dart:convert';

import '../services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_quiz_service.dart';
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

  Future<List<Question>> fetchQuestions({
    required String category,
    required String difficulty,
    required String languageCode,
    int count = 5,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int offlineTaken = prefs.getInt('offline_tests_taken') ?? 0;
      
      final hasInternet = await AppUtils.hasInternetConnection();
      
      // Eğer internet yoksa ve 3 test limitine ulaşılmadıysa offline havuzu kullan
      if (!hasInternet && offlineTaken < 3) {
        await prefs.setInt('offline_tests_taken', offlineTaken + 1);
        await Future.delayed(const Duration(seconds: 2)); // Loading animasyonu için ufak bir gecikme
        return await OfflineQuizService.getQuestions(languageCode: languageCode, count: count);
      } else if (!hasInternet && offlineTaken >= 3) {
        // Eğer internet yoksa ve 3 test dolduysa, yükleme ekranında takılmamak için hata fırlat
        throw Exception('offline_limit_reached');
      }

      final randomSeed = DateTime.now().millisecondsSinceEpoch;
      final allTests = await DatabaseHelper.instance.getAllTests();
      final previousQuestionRoots = <String>{};
      for (final test in allTests) {
        if (test.category == category && test.difficulty == difficulty) {
          for (final q in test.questions) {
            previousQuestionRoots.add(q.question.trim());
          }
        }
      }

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

  String _getSystemInstruction({
    required String languageCode,
    required String category,
    required String difficulty,
    required int count,
    required Set<String> previousQuestionRoots,
    required int randomSeed,
  }) {
    String previousTextBlockHeader;
    String noPreviousText;

    // Internal mapping to help AI understand the global context when not in Turkish
    final categoryMap = {
      'Genel Kültür': 'General Culture',
      'Yemek Kültürü': 'Food Culture',
      'Coğrafya': 'Geography',
      'Futbol': 'Football',
      'Dini': 'Religious',
      'Bilim': 'Science',
      'Sinema ve Dizi': 'Cinema & Series',
      'Tarih': 'History',
      'Magazin': 'Magazine',
      'Müzik': 'Music',
    };

    final promptCategory =
        languageCode == 'tr' ? category : (categoryMap[category] ?? category);

    switch (languageCode) {
      case 'tr':
        previousTextBlockHeader = "Daha önce kullanılan soru kökleri:";
        noPreviousText =
            "Bu kategori ve zorlukta daha önce kayıtlı bir soru yok.";
        break;
      case 'es':
        previousTextBlockHeader =
            "Raíces de preguntas utilizadas anteriormente:";
        noPreviousText =
            "No hay preguntas registradas para esta categoría y dificultad.";
        break;
      case 'fr':
        previousTextBlockHeader =
            "Racines de questions précédemment utilisées :";
        noPreviousText =
            "Aucune question enregistrée pour cette catégorie et difficulté.";
        break;
      case 'de':
        previousTextBlockHeader = "Zuvor verwendete Fragestämme:";
        noPreviousText =
            "Keine aufgezeichneten Fragen für diese Kategorie und Schwierigkeit.";
        break;
      case 'ar':
        previousTextBlockHeader = "جذور الأسئلة المستخدمة سابقا:";
        noPreviousText = "لا توجد أسئلة مسجلة لهذه الفئة والصعوبة حتى الآن.";
        break;
      case 'ru':
        previousTextBlockHeader = "Ранее использованные корни вопросов:";
        noPreviousText =
            "Для этой категории и сложности пока нет записанных вопросов.";
        break;
      default: // en
        previousTextBlockHeader = "Previously used question roots:";
        noPreviousText =
            "No recorded questions for this category and difficulty yet.";
    }

    final previousTextBlock = previousQuestionRoots.isNotEmpty
        ? "$previousTextBlockHeader\n${previousQuestionRoots.map((q) => "- $q").join("\n")}"
        : noPreviousText;

    switch (languageCode) {
      case 'tr':
        return '''Sen bir quiz yapay zekasısın. Şu kurallara uygun tam $count adet özgün soru üret:
- Kategori: '$promptCategory' - Zorluk: '$difficulty'

Zorluklar:
1. Kolay: Temel bilgi.
2. Orta: Yapılabilir.
3. Zor: Detay bilgi.
4. İmkansız: Çok teknik/nadir bilgi.

Kurallar:
- Süre az, sorular ve şıklar zorluğa orantılı olmalı.
- 4 şık, 1 doğru.
- Dil: Türkçe.
- Sorular birbirinden farklı olacak.
- Şunlara benzemesin:
$previousTextBlock
Çıktı SADECE bu JSON formatında olsun:
[{"question":"SORU","options":["A","B","C","D"],"correctIndex":0}]
Seed: $randomSeed
''';
      case 'es':
        return '''Eres una IA de quiz. Genera $count preguntas originales:
- Categoría: '$promptCategory' - Dificultad: '$difficulty'

Dificultades:
1. Fácil: Conocimiento básico.
2. Medio: Factible.
3. Difícil: Conocimiento detallado.
4. Imposible: Conocimiento muy técnico/raro.

Reglas:
- El tiempo es corto, las preguntas y las opciones deben ser proporcionales a la dificultad.
- 4 opciones, 1 correcta.
- Idioma: Español.
- ¡IMPORTANTE!: Si la categoría es 'History' (Historia), 'Geography' (Geografía) o 'General Culture' (Cultura General), enfócate en temas GLOBALES/MUNDIALES, no locales.
- Preguntas únicas.
- No coincidan con:
$previousTextBlock
Salida SOLO en este formato JSON:
[{"question":"PREGUNTA","options":["A","B","C","D"],"correctIndex":0}]
Seed: $randomSeed
''';
      case 'fr':
        return '''Tu es une IA de quiz. Génère $count questions originales :
- Catégorie : '$promptCategory' - Difficulté : '$difficulty'

Difficultés :
1. Facile : Connaissances de base.
2. Moyen : Faisable.
3. Difficile : Connaissances détaillées.
4. Impossible : Connaissances très techniques/rares.

Règles :
- Le temps est court, les questions et les options doivent être proportionnelles à la difficulté.
- 4 options, 1 correcte.
- Langue : Français.
- IMPORTANT : Si la catégorie est 'History' (Histoire), 'Geography' (Géographie) ou 'General Culture' (Culture Générale), concentre-toi sur des sujets MONDIAUX/GLOBAUX.
- Questions uniques.
- Ne pas ressembler à :
$previousTextBlock
Sortie UNIQUEMENT dans ce format JSON :
[{"question":"QUESTION","options":["A","B","C","D"],"correctIndex":0}]
Seed: $randomSeed
''';
      case 'ar':
        return '''أنت ذكاء اصطناعي للمسابقات. قم بإنشاء $count أسئلة أصلية:
- الفئة: '$promptCategory' - الصعوبة: '$difficulty'

الصعوبات:
1. سهل: معرفة أساسية.
2. متوسط: ممكن الحل.
3. صعب: معرفة تفصيلية.
4. مستحيل: معرفة تقنية/نادرة جداً.

القواعد:
- الوقت قصير، يجب أن تكون الأسئلة والخيارات متناسبة مع الصعوبة.
- 4 خيارات، 1 صحيح.
- اللغة: العربية.
- هام: إذا كانت الفئة هي 'History' (التاريخ) أو 'Geography' (الجغرافيا) أو 'General Culture' (الثقافة العامة)، ركز على المواضيع العالمية والدولية.
- أسئلة فريدة.
- لا تطابق:
$previousTextBlock
الإخراج فقط بتنسيق JSON هذا:
[{"question":"سؤال","options":["أ","ب","ج","د"],"correctIndex":0}]
Seed: $randomSeed
''';
      case 'ru':
        return '''Вы ИИ для викторин. Сгенерируйте $count оригинальных вопросов:
- Категория: '$promptCategory' - Сложность: '$difficulty'

Сложности:
1. Легко: Базовые знания.
2. Средне: Выполнимо.
3. Сложно: Детальные знания.
4. Невозможно: Очень технические/редкие знания.

Правила:
- Времени мало, вопросы и варианты должны быть пропорциональны сложности.
- 4 варианта, 1 правильный.
- Язык: Русский.
- ВАЖНО: Если категория — 'History' (История), 'Geography' (География) или 'General Culture' (Общая культура), сосредоточьтесь на МИРОВЫХ/ГЛОБАЛЬНЫХ темах.
- Уникальные вопросы.
- Не совпадать с:
$previousTextBlock
Вывод ТОЛЬКО в этом формате JSON:
[{"question":"ВОПРОС","options":["A","B","C","D"],"correctIndex":0}]
Seed: $randomSeed
''';
      default: // en
        return '''You are a quiz AI. Generate $count original questions:
- Category: '$promptCategory' - Difficulty: '$difficulty'

Difficulties:
1. Easy: Basic knowledge.
2. Medium: Doable.
3. Hard: Detailed knowledge.
4. Impossible: Very technical/rare knowledge.

Rules:
- Short time, questions and options should be proportional to difficulty.
- 4 options, 1 correct.
- Language: English.
- IMPORTANT: If the category is 'History', 'Geography', or 'General Culture', focus on WORLD/GLOBAL topics rather than specific local history.
- Unique questions.
- Don't match:
$previousTextBlock
Output ONLY in this JSON format:
[{"question":"QUESTION","options":["A","B","C","D"],"correctIndex":0}]
Seed: $randomSeed
''';
    }
  }
}
