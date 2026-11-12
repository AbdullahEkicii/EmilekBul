import 'dart:math';

/// Çarpanlı tahta modunun saf (Flutter'sız) mantığı.
///
/// Tahta 9 kareden oluşur; her karede gizli bir çarpan vardır:
/// 3 adet 3x, 3 adet 2x, 3 adet 1x. Oyuncu bir kare seçer, çarpan açılır,
/// soru sorulur ve doğru cevap `basePoints * çarpan` puan verir.
class BoardModeService {
  BoardModeService._();

  static const int tileCount = 9;
  static const int basePoints = 100;
  static const List<int> multipliers = [1, 2, 3];
  static const int copiesPerMultiplier = 3;

  /// Karıştırılmış tahta: her çarpandan [copiesPerMultiplier] adet.
  static List<int> buildBoard({Random? random}) {
    final board = <int>[
      for (final m in multipliers) ...List<int>.filled(copiesPerMultiplier, m),
    ];
    board.shuffle(random ?? Random());
    return board;
  }

  /// Tek bir soruyu puanlar: yanlışsa 0, doğruysa temel puan * çarpan.
  static int scoreQuestion({required bool correct, required int multiplier}) {
    if (!correct) return 0;
    return basePoints * multiplier;
  }

  /// [resolvedTiles] cevaplanmış (kilitlenmiş) kare sayısı; 9 olunca tahta biter.
  static bool isBoardComplete(int resolvedTiles) => resolvedTiles >= tileCount;

  /// Mümkün olan en yüksek toplam puan (her karede doğru cevap).
  static int get maxPossibleScore =>
      copiesPerMultiplier * multipliers.fold<int>(0, (sum, m) => sum + m) * basePoints;

  static int bestScore(int previousBest, int score) =>
      score > previousBest ? score : previousBest;
}
