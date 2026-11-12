import 'dart:math';
import 'token_economy.dart';

/// Token Arena mini oyunlarının saf (Flutter'sız) kuralları.
///
/// Her oyunda bahis [TokenEconomy.miniGameStake] jetondur. Kazanırsan bahis
/// [TokenEconomy.miniGamePayoutMultiplier] katına çıkar. Kaybedersen bahis gider.
/// Kazanma olasılıkları bilerek düşük tutuldu: jeton kıt bir kaynak.
class TokenArenaRules {
  TokenArenaRules._();

  // ------------------------------------------------------------ Yüksek-Düşük
  /// Arka arkaya kaç doğru tahmin gerekir
  static const int hiLoRounds = 3;

  /// Kart değeri 1 (As) ile 13 (K) arasında
  static int drawCard(Random random) => random.nextInt(13) + 1;

  /// Eşitlik her zaman kaybettirir
  static bool hiLoGuessCorrect({
    required int current,
    required int next,
    required bool guessHigher,
  }) {
    if (next == current) return false;
    return guessHigher ? next > current : next < current;
  }

  // ---------------------------------------------------------- Hafıza dizisi
  static const int memoryLength = 5;
  static const int memoryColors = 4;

  static List<int> buildSequence(Random random) =>
      List<int>.generate(memoryLength, (_) => random.nextInt(memoryColors));

  static bool memoryTapCorrect(List<int> sequence, int step, int tapped) =>
      step < sequence.length && sequence[step] == tapped;

  // ------------------------------------------------------------ Refleks
  static const int reflexTiles = 9;
  static const int reflexHitsNeeded = 6;

  /// Bu kadar kaçırılan hedeften sonra oyun biter
  static const int reflexMaxMisses = 2;

  static bool reflexWon(int hits) => hits >= reflexHitsNeeded;
  static bool reflexLost(int misses) => misses > reflexMaxMisses;

  // ------------------------------------------------------------ Ödül
  /// Kazanılınca geri ödenen toplam tutar (bahis dahil)
  static int payout(int stake) => stake * TokenEconomy.miniGamePayoutMultiplier;
}
