import 'package:emilekbul/constants/app_categories.dart';
import 'package:emilekbul/services/offline_category_questions.dart';
import 'package:emilekbul/services/offline_quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineQuizService & offlineCategoryQuestions', () {
    test('every core category has valid offline TR and EN questions', () {
      for (final category in AppCategories.categories) {
        final trList = offlineCategoryQuestions['tr']?[category.name];
        final enList = offlineCategoryQuestions['en']?[category.name];

        expect(trList, isNotNull, reason: 'Missing TR pool for ${category.name}');
        expect(enList, isNotNull, reason: 'Missing EN pool for ${category.name}');
        expect(trList!.length, greaterThanOrEqualTo(5));
        expect(enList!.length, greaterThanOrEqualTo(5));

        for (final q in [...trList, ...enList]) {
          expect(q.question.trim(), isNotEmpty);
          expect(q.options.length, 4);
          expect(q.correctIndex, inInclusiveRange(0, 3));
        }
      }
    });

    test('getCategoryQuestions returns requested count and honors exclude', () {
      final first = OfflineQuizService.getCategoryQuestions(
        category: 'Bilim',
        languageCode: 'tr_TR',
        count: 5,
      );
      expect(first.length, 5);

      final excluded = {first.first.question};
      final second = OfflineQuizService.getCategoryQuestions(
        category: 'Bilim',
        languageCode: 'tr',
        count: 5,
        exclude: excluded,
      );
      expect(second.length, 5);
      expect(second.any((q) => excluded.contains(q.question)), isFalse);
    });

    test('unknown language falls back to EN pool cleanly', () {
      final result = OfflineQuizService.getCategoryQuestions(
        category: 'Tarih',
        languageCode: 'pt',
        count: 5,
      );
      expect(result.length, 5);
    });
  });
}
