import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/services/adaptive_service.dart';

void main() {
  test('eşit beceri ve zorlukta şans düzeltmeli başarı 0.625', () {
    expect(AdaptiveService.expected(1000, 1000), closeTo(0.625, 1e-9));
  });

  test('beceri arttıkça beklenen başarı artar, zorluk arttıkça azalır', () {
    expect(AdaptiveService.expected(1200, 1000), greaterThan(AdaptiveService.expected(1000, 1000)));
    expect(AdaptiveService.expected(1000, 1200), lessThan(AdaptiveService.expected(1000, 1000)));
  });

  test('beklenen başarı alt sınırı şans seviyesidir (0.25)', () {
    expect(AdaptiveService.expected(0, 4000), greaterThanOrEqualTo(0.25));
    expect(AdaptiveService.expected(0, 4000), closeTo(0.25, 1e-3));
  });

  test('zorluk etiketi başlangıç puanları', () {
    expect(AdaptiveService.initialDifficulty('Kolay'), 900);
    expect(AdaptiveService.initialDifficulty('Orta'), 1000);
    expect(AdaptiveService.initialDifficulty('Zor'), 1100);
    expect(AdaptiveService.initialDifficulty('İmkansız'), 1200);
  });

  test('ustalık seviyeleri eşikleri doğru uygular', () {
    expect(const MasteryInfo('x', 5, 5).level, 0); // az cevap
    expect(const MasteryInfo('x', 10, 4).level, 1); // %40
    expect(const MasteryInfo('x', 20, 12).level, 2); // %60, 50 cevap altı
    expect(const MasteryInfo('x', 60, 42).level, 3); // %70, 50+
    expect(const MasteryInfo('x', 160, 124).level, 4); // %77, 150+
    expect(const MasteryInfo('x', 320, 288).level, 5); // %90, 300+
  });
}
