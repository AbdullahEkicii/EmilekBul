import '../models/question.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import '../models/test_result.dart';
import '../services/database_helper.dart';

class AiApiService {
  final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: dotenv.env['API_KEY']!,
  );

  Future<List<Question>> fetchQuestions({
    required String category,
    required String difficulty,
    int count = 5,
  }) async {
    try {
      final randomSeed = DateTime.now().millisecondsSinceEpoch;

      /// 🔍 1. Önceki test sonuçlarını getir
      final allTests = await DatabaseHelper.instance.getAllTests();

      /// 🔍 2. Kategori ve zorluk filtrele
      final previousQuestionRoots = <String>{};
      for (final test in allTests) {
        if (test.category == category && test.difficulty == difficulty) {
          for (final q in test.questions) {
            previousQuestionRoots.add(q.question.trim());
          }
        }
      }

      /// 🧠 3. Eski soru köklerini formatla
      final previousTextBlock = previousQuestionRoots.isNotEmpty
          ? "Daha önce kullanılan soru kökleri:\n${previousQuestionRoots.map((q) => "- $q").join("\n")}"
          : "Bu kategori ve zorlukta daha önce kayıtlı bir soru yok.";

      /// 🧾 4. Prompt’u oluştur
      final prompt =
          '''
Sen yaratıcı bir quiz yapay zekasısın. Aşağıdaki kurallara uygun tam $count adet yeni, özgün soru üret.

- Kategori: '$category'
- Zorluk: '$difficulty'
- Her soru 4 şıklı, sadece biri doğru.
- Şıklar benzer görünsün ama doğru olan net olsun.
- Türkçe sorular ve cevaplar olsun.
- Sorular birbirinden tamamen farklı olsun; aynı kök soru tekrar etmesin.
- Aşağıdaki soru köklerine **benzemesin**:

$previousTextBlock

Çıktı, aşağıdaki JSON formatında ve SADECE geçerli bir JSON dizi olmalı:
[
  {
    "question": "SORU 1",
    "options": ["A1","B1","C1","D1"],
    "correctIndex": 2
  },
  ...
]

Rastgelelik faktörü: $randomSeed
''';

      /// 📡 5. API isteğini gönder
      final content = Content.text(prompt);
      final response = await _model.generateContent([content]);
      final text = response.text;

      /// ✅ 6. JSON veriyi ayıkla
      final jsonStart = text?.indexOf('[') ?? -1;
      final jsonEnd = text?.lastIndexOf(']') ?? -1;

      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('Yapay zekadan beklenen formatta veri gelmedi.');
      }

      final jsonString = text!.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => Question.fromJson(e)).toList();
    } catch (e, s) {
      print('AI API HATASI: $e\n$s');
      rethrow;
    }
  }
}
