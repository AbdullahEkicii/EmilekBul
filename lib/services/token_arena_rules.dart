import 'dart:math';

import 'token_economy.dart';

/// Token Arena mini oyunlarının saf kuralları ve kasa avantajı ("house edge") hesapları.
/// UI'dan tamamen ayrıdır, tüm olasılık ve ödeme çarpanları testlerle doğrulanır.
class TokenArenaRules {
  // ------------------------------------------------------------ Yüksek / Düşük
  static const int hiLoRounds = 3;

  static int drawCard(Random random) => random.nextInt(13) + 1; // 1..13

  /// Eşitlik durumunda kasa kazanır (~%7.7 ekstra kasa avantajı).
  static bool hiLoGuessCorrect({
    required int current,
    required int next,
    required bool guessHigher,
  }) {
    if (next == current) return false;
    return guessHigher ? next > current : next < current;
  }

  /// Optimal strateji + eşitlikte kasa kuralıyla ~%31 kazanma şansı ve 1.8x ödeme.
  static double hiLoExpectedValue() {
    const approxOptimalRoundWin = 10 / 13; // ortalamada ~%76.9 tek tur
    final threeRoundWin =
        approxOptimalRoundWin * approxOptimalRoundWin * approxOptimalRoundWin;
    return threeRoundWin * TokenEconomy.miniGamePayoutMultiplier;
  }

  // ------------------------------------------------------------- Hafıza Dizisi
  static const int memoryLength = 5;
  static const int memoryColors = 4;

  static List<int> buildSequence(Random random) =>
      List<int>.generate(memoryLength, (_) => random.nextInt(memoryColors));

  static bool memoryTapCorrect(List<int> seq, int step, int color) =>
      step < seq.length && seq[step] == color;

  // ------------------------------------------------------------- Refleks Vuruşu
  static const int reflexTiles = 9;
  static const int reflexHitsNeeded = 7;
  static const int reflexMaxMisses = 2;

  /// Karelerin görünme süresi ilerledikçe hızlanır (800ms -> 420ms).
  static int reflexWindowMs(int hits) => (800 - hits * 60).clamp(420, 800);

  static bool reflexWon(int hits) => hits >= reflexHitsNeeded;
  static bool reflexLost(int misses) => misses > reflexMaxMisses;

  // ------------------------------------------------------------ Mayınlı Kasa
  static const int minesTotalTiles = 12;
  static const int minesBombCount = 4;
  static const List<double> minesMultipliers = [1.30, 1.95, 3.20, 5.60, 9.50];

  static int get minesMaxSafePicks => minesMultipliers.length;

  /// 12 hücre içinde rastgele 4 mayın yerleştirir.
  static Set<int> generateMines(Random random) {
    final mines = <int>{};
    while (mines.length < minesBombCount) {
      mines.add(random.nextInt(minesTotalTiles));
    }
    return mines;
  }

  static double minesMultiplierFor(int safeRevealed) {
    if (safeRevealed <= 0) return 0.0;
    final idx = (safeRevealed - 1).clamp(0, minesMultipliers.length - 1);
    return minesMultipliers[idx];
  }

  static int minesPayout(int stake, int safeRevealed) =>
      (stake * minesMultiplierFor(safeRevealed)).floor();

  /// Arka arkaya [safeRevealed] güvenli kare açma olasılığı.
  static double minesSurvivalProbability(int safeRevealed) {
    if (safeRevealed <= 0) return 1.0;
    var p = 1.0;
    final safeTotal = minesTotalTiles - minesBombCount;
    for (var i = 0; i < safeRevealed; i++) {
      p *= (safeTotal - i) / (minesTotalTiles - i);
    }
    return p;
  }

  /// Her kademede beklenen değer < 1.0 (kasa %13.3 - %32.8 avantajlı).
  static double minesExpectedValue(int safeRevealed) =>
      minesSurvivalProbability(safeRevealed) * minesMultiplierFor(safeRevealed);

  // ------------------------------------------------------------- Çarpan Ruleti
  /// 10 eşit ağırlıklı dilim: EV = (0*4 + 0.5*3 + 1.5*2 + 3.5*1) / 10 = 0.80.
  static const List<double> wheelMultipliers = [
    0.0,
    0.5,
    1.5,
    0.0,
    0.5,
    3.5,
    0.0,
    1.5,
    0.5,
    0.0,
  ];

  static int spinWheelIndex(Random random) =>
      random.nextInt(wheelMultipliers.length);

  static int wheelPayout(int stake, int slotIndex) {
    final mult = wheelMultipliers[slotIndex % wheelMultipliers.length];
    return (stake * mult).floor();
  }

  static double wheelExpectedValue() =>
      wheelMultipliers.reduce((a, b) => a + b) / wheelMultipliers.length;

  // ---------------------------------------------------------------- Genel Ödül
  static int payout(int stake, {double? multiplier}) =>
      (stake * (multiplier ?? TokenEconomy.miniGamePayoutMultiplier)).floor();
}
