import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'database_helper.dart';
import 'ai_api_service.dart';

class QuestionPoolService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'question_bank';
  static final Random _random = Random();

  /// Hibrit Soru Getirici (Yerel Önbellek -> Bulut Havuzu -> AI Üretimi -> Aralıklı Tekrar)
  static Future<List<Question>> getHybridQuestions({
    required String category,
    required String difficulty,
    required String languageCode,
    int count = 5,
    bool includeSpacedRepetition = true,
  }) async {
    List<Question> resultQuestions = [];
    final neededCount = count;

    // 1. ADIM: Aralıklı Tekrar (Kullanıcının 4-5 test önce yanlış yaptığı 1 soruyu pekiştirme amaçlı ekle)
    if (includeSpacedRepetition) {
      try {
        final spaced = await DatabaseHelper.instance.getSpacedRepetitionQuestions(
          category,
          limit: 1,
          minTestsAgo: 4,
        );
        if (spaced.isNotEmpty) {
          resultQuestions.addAll(spaced);
          debugPrint('🧠 Aralıklı Tekrar: 1 adet geçmişte yanlış yapılan soru eklendi.');
        }
      } catch (e) {
        debugPrint('Aralıklı tekrar okuma hatası: $e');
      }
    }

    // 2. ADIM: Yerel SQLite Önbelleğinden Görülmemiş Soruları Çek
    final remainingFromLocal = neededCount - resultQuestions.length;
    if (remainingFromLocal > 0) {
      try {
        final localQuestions = await DatabaseHelper.instance.getUnseenCachedQuestions(
          category: category,
          difficulty: difficulty,
          languageCode: languageCode,
          count: remainingFromLocal,
        );
        if (localQuestions.isNotEmpty) {
          resultQuestions.addAll(localQuestions);
          debugPrint('💾 Yerel Önbellek: ${localQuestions.length} soru yerelden yüklendi.');
        }
      } catch (e) {
        debugPrint('Yerel önbellek okuma hatası: $e');
      }
    }

    // Yeterli soruya ulaşıldıysa hemen dön (0ms bekleme)
    if (resultQuestions.length >= neededCount) {
      return resultQuestions.take(neededCount).toList();
    }

    // 3. ADIM: Firestore Merkezi Bulut Havuzundan Soru Çek
    final remainingFromCloud = neededCount - resultQuestions.length;
    if (remainingFromCloud > 0) {
      try {
        final cloudQuestions = await fetchQuestionsFromFirestorePool(
          category: category,
          difficulty: difficulty,
          languageCode: languageCode,
          count: remainingFromCloud,
        );
        if (cloudQuestions.isNotEmpty) {
          resultQuestions.addAll(cloudQuestions);
          // Yerel önbelleğe de kaydet
          await DatabaseHelper.instance.saveCachedQuestions(
            cloudQuestions,
            category: category,
            difficulty: difficulty,
            languageCode: languageCode,
          );
          debugPrint('☁️ Bulut Havuzu: ${cloudQuestions.length} soru Firestore\'dan çekildi.');
        }
      } catch (e) {
        debugPrint('Bulut havuzu okuma hatası: $e');
      }
    }

    // Yeterli soruya ulaşıldıysa hemen dön
    if (resultQuestions.length >= neededCount) {
      return resultQuestions.take(neededCount).toList();
    }

    // 4. ADIM: Havuz Tamamen Tükendiyse -> Yeni Nesil Taksonomik AI Çağrısı Yap
    final remainingFromAi = neededCount - resultQuestions.length;
    if (remainingFromAi > 0) {
      debugPrint('🤖 Havuz Tükendi: $remainingFromAi soru için yeni nesil AI çağrısı yapılıyor...');
      try {
        final aiService = AiApiService();
        // Verimlilik için en az 5 soru üret, fazlasını yerel ve bulut havuzuna kaydet
        final produceCount = max(remainingFromAi, 5);
        final aiQuestions = await aiService.fetchQuestions(
          category: category,
          difficulty: difficulty,
          languageCode: languageCode,
          count: produceCount,
        );

        if (aiQuestions.isNotEmpty) {
          resultQuestions.addAll(aiQuestions.take(remainingFromAi));

          // Üretilen tüm soruları arka planda hem yerel SQLite'a hem de Firestore Merkezi Havuzuna yükle
          _syncNewlyGeneratedQuestions(
            aiQuestions,
            category: category,
            difficulty: difficulty,
            languageCode: languageCode,
          );
        }
      } catch (aiErr) {
        debugPrint('AI soru üretim hatası: $aiErr');
      }
    }

    // 5. ADIM: Eğer AI veya internet hatası olduysa ve hala eksik soru varsa -> Önbellekteki tüm soruları geri dönüştür
    if (resultQuestions.length < neededCount) {
      try {
        final recycledQuestions = await DatabaseHelper.instance.getRecycledCachedQuestions(
          category: category,
          difficulty: difficulty,
          languageCode: languageCode,
          count: neededCount - resultQuestions.length,
        );
        if (recycledQuestions.isNotEmpty) {
          resultQuestions.addAll(recycledQuestions);
          debugPrint('♻️ Geri Dönüştürülmüş Önbellek: ${recycledQuestions.length} soru eklendi.');
        }
      } catch (recycleErr) {
        debugPrint('Önbellek geri dönüştürme hatası: $recycleErr');
      }
    }

    return resultQuestions.take(neededCount).toList();
  }

  /// Çok Dilli Düello İçin Hibrit Soru Getirici
  static Future<List<Question>> getHybridMultilingualQuestions({
    required String category,
    required String difficulty,
    required List<String> languageCodes,
    int count = 5,
  }) async {
    // 1. Önce Firestore havuzundan çok dilli eşleşen soruları ara
    try {
      final cloudQuestions = await fetchMultilingualFromFirestorePool(
        category: category,
        difficulty: difficulty,
        languageCodes: languageCodes,
        count: count,
      );
      if (cloudQuestions.length >= count) {
        debugPrint('☁️ Düello Havuzu: ${cloudQuestions.length} çok dilli soru havuzdan çekildi.');
        return cloudQuestions.take(count).toList();
      }
    } catch (e) {
      debugPrint('Düello bulut havuzu hatası: $e');
    }

    // 2. Havuzda yoksa çok dilli AI üretimi yap
    debugPrint('🤖 Düello: Çok dilli AI üretimi başlatılıyor...');
    final aiService = AiApiService();
    final questions = await aiService.fetchMultilingualQuestions(
      category: category,
      difficulty: difficulty,
      languageCodes: languageCodes,
      count: count,
    );

    // Üretilen soruları çok dilli olarak Firestore havuzuna kaydet
    if (questions.isNotEmpty) {
      uploadMultilingualQuestionsToPool(
        questions: questions,
        category: category,
        difficulty: difficulty,
        languageCodes: languageCodes,
      );
    }

    return questions;
  }

  /// Firestore Merkezi Havuzundan Tek Dilli Soru Çekme
  static Future<List<Question>> fetchQuestionsFromFirestorePool({
    required String category,
    required String difficulty,
    required String languageCode,
    required int count,
  }) async {
    final partitionKey = '${category}_$difficulty'.replaceAll('/', '_');
    var querySnap = await _firestore
        .collection(_collectionName)
        .doc(partitionKey)
        .collection('questions')
        .where('languages', arrayContains: languageCode)
        .limit(count * 3)
        .get();

    // Eğer languages array indeksinde bulunamadıysa genel belgeleri çek ve translations map'ini kontrol et
    if (querySnap.docs.isEmpty) {
      querySnap = await _firestore
          .collection(_collectionName)
          .doc(partitionKey)
          .collection('questions')
          .limit(count * 3)
          .get();
    }

    if (querySnap.docs.isEmpty) return [];

    final docs = List<QueryDocumentSnapshot>.from(querySnap.docs)..shuffle(_random);
    List<Question> questions = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final translations = data['translations'] as Map<String, dynamic>?;
      if (translations != null && translations.containsKey(languageCode)) {
        final langData = translations[languageCode] as Map<String, dynamic>;
        questions.add(Question(
          question: langData['question'] ?? '',
          options: List<String>.from(langData['options'] ?? []),
          correctIndex: (langData['correctIndex'] as num?)?.toInt() ?? 0,
        ));
      } else if (languageCode == 'tr' && data['question'] != null) {
        questions.add(Question(
          question: data['question'] ?? '',
          options: List<String>.from(data['options'] ?? []),
          correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
        ));
      }

      if (questions.length >= count) break;
    }
    return questions;
  }

  /// Firestore Merkezi Havuzundan Çok Dilli Soru Çekme
  static Future<List<Question>> fetchMultilingualFromFirestorePool({
    required String category,
    required String difficulty,
    required List<String> languageCodes,
    required int count,
  }) async {
    final partitionKey = '${category}_$difficulty'.replaceAll('/', '_');
    final primaryLang = languageCodes.isNotEmpty ? languageCodes.first : 'tr';

    final querySnap = await _firestore
        .collection(_collectionName)
        .doc(partitionKey)
        .collection('questions')
        .limit(count * 3)
        .get();

    if (querySnap.docs.isEmpty) return [];

    List<Question> validQuestions = [];
    final docs = List<QueryDocumentSnapshot>.from(querySnap.docs)..shuffle(_random);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final translations = data['translations'] as Map<String, dynamic>?;
      if (translations == null) continue;

      // İstenen tüm diller bu soruda mevcut mu?
      bool hasAllLanguages = true;
      for (final lang in languageCodes) {
        if (!translations.containsKey(lang)) {
          hasAllLanguages = false;
          break;
        }
      }

      if (hasAllLanguages) {
        final primaryData = translations[primaryLang] as Map<String, dynamic>;
        final Map<String, dynamic> transMap = {};
        for (final lang in languageCodes) {
          final langData = translations[lang] as Map<String, dynamic>?;
          if (langData != null) {
            transMap[lang] = {
              'question': langData['question'] ?? '',
              'options': List<String>.from(langData['options'] ?? []),
            };
          }
        }

        final q = Question(
          question: primaryData['question'] ?? '',
          options: List<String>.from(primaryData['options'] ?? []),
          correctIndex: (primaryData['correctIndex'] as num?)?.toInt() ?? 0,
          translations: transMap,
        );
        validQuestions.add(q);
      }

      if (validQuestions.length >= count) break;
    }

    return validQuestions;
  }

  /// Yeni üretilen soruları hem SQLite'a hem Firestore'a asenkron kaydetme
  static void _syncNewlyGeneratedQuestions(
    List<Question> questions, {
    required String category,
    required String difficulty,
    required String languageCode,
  }) {
    // 1. Yerel SQLite'a kaydet
    DatabaseHelper.instance.saveCachedQuestions(
      questions,
      category: category,
      difficulty: difficulty,
      languageCode: languageCode,
    );

    // 2. Firestore Merkezi Havuzuna yükle (Arka planda)
    Future.microtask(() async {
      try {
        final partitionKey = '${category}_$difficulty'.replaceAll('/', '_');
        final batch = _firestore.batch();

        for (final q in questions) {
          final qRoot = q.question.toLowerCase().replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]'), '').trim();
          final docId = 'q_${category.hashCode.abs()}_${qRoot.hashCode.abs()}';
          final docRef = _firestore
              .collection(_collectionName)
              .doc(partitionKey)
              .collection('questions')
              .doc(docId);

          batch.set(
            docRef,
            {
              'category': category,
              'difficulty': difficulty,
              'languages': FieldValue.arrayUnion([languageCode]),
              'translations': {
                languageCode: {
                  'question': q.question,
                  'options': q.options,
                  'correctIndex': q.correctIndex,
                },
              },
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
        debugPrint('☁️ Yeni üretilen ${questions.length} soru Firestore soru bankasına kaydedildi.');
      } catch (e) {
        debugPrint('Firestore soru havuzuna yükleme hatası: $e');
      }
    });
  }

  /// Çok dilli üretilen soruları Firestore havuzuna kaydetme
  static void uploadMultilingualQuestionsToPool({
    required List<Question> questions,
    required String category,
    required String difficulty,
    required List<String> languageCodes,
  }) {
    Future.microtask(() async {
      try {
        final partitionKey = '${category}_$difficulty'.replaceAll('/', '_');
        final batch = _firestore.batch();

        for (final q in questions) {
          final qRoot = q.question.toLowerCase().replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]'), '').trim();
          final docId = 'q_${category.hashCode.abs()}_${qRoot.hashCode.abs()}';
          final docRef = _firestore
              .collection(_collectionName)
              .doc(partitionKey)
              .collection('questions')
              .doc(docId);

          Map<String, dynamic> translationsMap = {};
          if (q.translations != null) {
            for (final entry in q.translations!.entries) {
              if (entry.value is Map) {
                final mapVal = entry.value as Map;
                translationsMap[entry.key] = {
                  'question': mapVal['question']?.toString() ?? '',
                  'options': List<String>.from(mapVal['options'] ?? []),
                  'correctIndex': q.correctIndex,
                };
              }
            }
          }

          // Ana dili de ekle
          final primaryLang = languageCodes.isNotEmpty ? languageCodes.first : 'tr';
          if (!translationsMap.containsKey(primaryLang)) {
            translationsMap[primaryLang] = {
              'question': q.question,
              'options': q.options,
              'correctIndex': q.correctIndex,
            };
          }

          batch.set(
            docRef,
            {
              'category': category,
              'difficulty': difficulty,
              'languages': languageCodes,
              'translations': translationsMap,
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
        debugPrint('☁️ ${questions.length} adet çok dilli soru Firestore havuzuna kaydedildi.');
      } catch (e) {
        debugPrint('Çok dilli soru havuzuna yükleme hatası: $e');
      }
    });
  }
}
