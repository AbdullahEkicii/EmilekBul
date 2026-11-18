import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/services/ad_grace.dart';

void main() {
  group('AdGrace.isActiveFor', () {
    test('yeni kullanıcı ilk gün ve test eşiği altındayken aktif', () {
      expect(
        AdGrace.isActiveFor(
          daysSinceFirstOpen: 0,
          completedTests: 0,
          graceDaysOverride: 2,
          graceTestsOverride: 3,
        ),
        isTrue,
      );
      expect(
        AdGrace.isActiveFor(
          daysSinceFirstOpen: 1,
          completedTests: 2,
          graceDaysOverride: 2,
          graceTestsOverride: 3,
        ),
        isTrue,
      );
    });

    test('test eşiğine ulaşan aktif kullanıcıda sessiz dönem biter', () {
      expect(
        AdGrace.isActiveFor(
          daysSinceFirstOpen: 0,
          completedTests: 3,
          graceDaysOverride: 2,
          graceTestsOverride: 3,
        ),
        isFalse,
      );
    });

    test('gün eşiği dolduğunda az test çözse bile sessiz dönem biter', () {
      expect(
        AdGrace.isActiveFor(
          daysSinceFirstOpen: 2,
          completedTests: 1,
          graceDaysOverride: 2,
          graceTestsOverride: 3,
        ),
        isFalse,
      );
    });
  });
}
