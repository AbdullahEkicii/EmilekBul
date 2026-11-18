import 'question_report_service.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_categories.dart';
import '../utils/app_utils.dart';
import 'ai_api_service.dart';
import 'analytics_service.dart';
import 'offline_quiz_service.dart';

class QuestionPoolService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'question_bank';
  static final Random _random = Random();

  // Kısa süreli bellek içi havuz önbelleği (aynı partition için tekrar okumayı önler)
  static const Duration _poolCacheTtl = Duration(minutes: 10);
  static const int _poolCacheMaxEntries = 8;
  static final Map<String, _PoolCacheEntry> _poolCache = {};

  /// Okuma maliyeti: count*3 yerine count*2 (en az count+2)
  static int _poolLimit(int count) => max(count * 2, count + 2);

  static Future<List<Map<String, dynamic>>> _cachedPoolDocs(
    String cacheKey,
    int limit,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) async {
    final now = DateTime.now();
    final hit = _poolCache[cacheKey];
    if (hit != null &&
        now.difference(hit.fetchedAt) < _poolCacheTtl &&
        hit.limit >= limit &&
        hit.docs.isNotEmpty) {
      return List<Map<String, dynamic>>.from(hit.docs);
    }
    final docs = await fetch();
    if (docs.isNotEmpty) {
      _poolCache.remove(cacheKey);
      while (_poolCache.length >= _poolCacheMaxEntries) {
        _poolCache.remove(_poolCache.keys.first); // en eski
      }
      _poolCache[cacheKey] = _PoolCacheEntry(docs, limit, now);
    }
    return List<Map<String, dynamic>>.from(docs);
  }

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
    // Oyuncunun bildirdiği sorular bir daha gösterilmez (yerel filtre)
    final reportedKeys = await QuestionReportService.reportedKeys();
    List<Question> keepOk(List<Question> l) => QuestionReportService.filterReported(l, reportedKeys);

    // 1. ADIM: Aralıklı Tekrar (Kullanıcının 4-5 test önce yanlış yaptığı 1 soruyu pekiştirme amaçlı ekle)
    if (includeSpacedRepetition) {
      try {
        final spaced = await DatabaseHelper.instance.getSpacedRepetitionQuestions(
          category,
          limit: 1,
          minTestsAgo: 4,
        );
        if (spaced.isNotEmpty) {
          resultQuestions.addAll(keepOk(spaced));
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
        // Eski, aşırı uzun sorular önbellekte kalmış olabilir: okurken ele
        localQuestions.retainWhere(AiApiService.isCompactQuestion);
        if (localQuestions.isNotEmpty) {
          resultQuestions.addAll(keepOk(localQuestions));
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
          resultQuestions.addAll(keepOk(cloudQuestions));
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
        _logFallback('ai', category);
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
        recycledQuestions.retainWhere(AiApiService.isCompactQuestion);
        if (recycledQuestions.isNotEmpty) {
          resultQuestions.addAll(keepOk(recycledQuestions));
          debugPrint('♻️ Geri Dönüştürülmüş Önbellek: ${recycledQuestions.length} soru eklendi.');
          _logFallback('recycled', category);
        }
      } catch (recycleErr) {
        debugPrint('Önbellek geri dönüştürme hatası: $recycleErr');
      }
    }

    // 6. ADIM: Hala eksikse yerleşik çevrimdışı başlangıç sorularıyla tamamla (tekrarsız)
    if (resultQuestions.length < neededCount) {
      try {
        final existing = resultQuestions.map((q) => q.question).toSet();
        final starter = OfflineQuizService.getCategoryQuestions(
          category: category,
          languageCode: languageCode,
          count: neededCount - resultQuestions.length,
          exclude: existing,
        );
        if (starter.isNotEmpty) {
          resultQuestions.addAll(keepOk(starter));
          debugPrint('🛟 Çevrimdışı başlangıç: ${starter.length} soru eklendi.');
          _logFallback('offline_starter', category);
        }
      } catch (e) {
        debugPrint('Çevrimdışı başlangıç soruları hatası: $e');
      }
    }

    return resultQuestions.take(neededCount).toList();
  }

  static void _logFallback(String stage, String category) {
    try {
      AnalyticsService.logCustomEvent(
        name: 'questions_fallback',
        parameters: {'stage': stage, 'category': category},
      );
    } catch (_) {}
  }

  /// İlk açılışta (dil başına bir kez) popüler kategoriler için 'Kolay' soruları
  /// Firestore havuzundan çekip yerel önbelleğe yazar. AI çağrısı yapmaz; hatalar sessizdir.
  static Future<void> prefetchStarterQuestions({required String languageCode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flagKey = 'starter_prefetch_done_$languageCode';
      if (prefs.getBool(flagKey) ?? false) return;
      if (!await AppUtils.hasInternetConnection()) return;

      final categories = <String>['Genel Kültür'];
      for (final c in AppCategories.categories) {
        if (categories.length >= 3) break;
        if (c.name != 'Genel Kültür') categories.add(c.name);
      }

      const difficulty = 'Kolay';
      int saved = 0;
      for (final category in categories) {
        try {
          final qs = await fetchQuestionsFromFirestorePool(
            category: category,
            difficulty: difficulty,
            languageCode: languageCode,
            count: 10,
          ).timeout(const Duration(seconds: 10));
          if (qs.isEmpty) continue;
          await DatabaseHelper.instance.saveCachedQuestions(
            qs,
            category: category,
            difficulty: difficulty,
            languageCode: languageCode,
          );
          saved += qs.length;
        } catch (e) {
          debugPrint('Starter prefetch ($category) hatası: $e');
        }
      }
      // Havuz boşsa bayrak konmaz; sonraki açılışta tekrar denenir
      if (saved > 0) {
        await prefs.setBool(flagKey, true);
        debugPrint('📦 Starter prefetch: $saved soru yerele kaydedildi ($languageCode).');
      }
    } catch (e) {
      debugPrint('Starter prefetch hatası: $e');
    }
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
    final limit = _poolLimit(count);
    final fetched = await _cachedPoolDocs('s|$partitionKey|$languageCode', limit, () async {
      var querySnap = await _firestore
          .collection(_collectionName)
          .doc(partitionKey)
          .collection('questions')
          .where('languages', arrayContains: languageCode)
          .limit(limit)
          .get();

      // Eğer languages array indeksinde bulunamadıysa genel belgeleri çek ve translations map'ini kontrol et
      if (querySnap.docs.isEmpty) {
        querySnap = await _firestore
            .collection(_collectionName)
            .doc(partitionKey)
            .collection('questions')
            .limit(limit)
            .get();
      }
      return querySnap.docs.map((d) => d.data()).toList();
    });

    if (fetched.isEmpty) return [];

    final docs = fetched..shuffle(_random);
    List<Question> questions = [];
    void addIfCompact(Question q) {
      if (AiApiService.isCompactQuestion(q)) questions.add(q);
    }

    for (final data in docs) {
      if (QuestionReportService.isCommunityFlagged(data)) continue; // çok bildirilen soru
      final translations = data['translations'] as Map<String, dynamic>?;
      if (translations != null && translations.containsKey(languageCode)) {
        final langData = translations[languageCode] as Map<String, dynamic>;
        addIfCompact(Question(
          question: langData['question'] ?? '',
          options: List<String>.from(langData['options'] ?? []),
          correctIndex: (langData['correctIndex'] as num?)?.toInt() ?? 0,
        ));
      } else if (languageCode == 'tr' && data['question'] != null) {
        addIfCompact(Question(
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

    final limit = _poolLimit(count);
    final fetched = await _cachedPoolDocs('m|$partitionKey', limit, () async {
      final querySnap = await _firestore
          .collection(_collectionName)
          .doc(partitionKey)
          .collection('questions')
          .limit(limit)
          .get();
      return querySnap.docs.map((d) => d.data()).toList();
    });

    if (fetched.isEmpty) return [];

    List<Question> validQuestions = [];
    final docs = fetched..shuffle(_random);

    for (final data in docs) {
      if (QuestionReportService.isCommunityFlagged(data)) continue; // çok bildirilen soru
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

class _PoolCacheEntry {
  final List<Map<String, dynamic>> docs;
  final int limit;
  final DateTime fetchedAt;
  _PoolCacheEntry(this.docs, this.limit, this.fetchedAt);
}
