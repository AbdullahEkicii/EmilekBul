import 'dart:math';

/// Bot kişiliği: aynı bot her maçta tutarlı davranır (uid'den türetilir),
/// ama botlar birbirinden doğruluk, hız ve sohbet sıklığı açısından ayrışır.
class BotPersona {
  /// Doğruluk kayması (-0.04 .. +0.04)
  final double skill;

  /// Süre çarpanı (düşük = hızlı çözer) (0.85 .. 1.20)
  final double pace;

  /// Lobi sohbet olasılığı (0 .. 1)
  final double chattiness;

  /// İnsan öndeyken zorlayan, geride kalınca rahatlayan tip mi
  final bool competitive;

  const BotPersona({
    required this.skill,
    required this.pace,
    required this.chattiness,
    required this.competitive,
  });

  factory BotPersona.fromSeed(String seed) {
    final rnd = Random(_hash(seed));
    return BotPersona(
      skill: rnd.nextDouble() * 0.08 - 0.04,
      pace: 0.85 + rnd.nextDouble() * 0.35,
      chattiness: 0.2 + rnd.nextDouble() * 0.8,
      competitive: rnd.nextBool(),
    );
  }

  static int _hash(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }
}

/// Bir sorudaki bot kararı: doğru cevap olasılığı ve çözme süresi.
class BotTuning {
  final double accuracy;
  final int delayMs;
  const BotTuning(this.accuracy, this.delayMs);
}

class BotDifficultyCurve {
  BotDifficultyCurve._();

  /// Zorluğa göre taban doğruluk ve süre aralığı (min, aralık boyu) ms cinsinden.
  static ({double accuracy, int minMs, int spanMs}) _base(String difficulty) {
    switch (difficulty.toLowerCase().trim()) {
      case 'kolay':
      case 'easy':
        return (accuracy: 0.81, minMs: 7000, spanMs: 6000);
      case 'zor':
      case 'hard':
        return (accuracy: 0.53, minMs: 13000, spanMs: 8000);
      case 'imkansız':
      case 'imkansiz':
      case 'impossible':
        return (accuracy: 0.375, minMs: 15000, spanMs: 8000);
      case 'orta':
      case 'medium':
      default:
        return (accuracy: 0.74, minMs: 10000, spanMs: 8000);
    }
  }

  /// [scoreGap] = insan skoru - bot skoru (pozitifse insan öndedir).
  /// [botStreak] = bot'un art arda doğru sayısı.
  static BotTuning decide({
    required String difficulty,
    required BotPersona persona,
    required int botStreak,
    required int scoreGap,
    required int questionIndex,
    required int totalQuestions,
    required bool lastAnswerWrong,
    required Random random,
  }) {
    final base = _base(difficulty);

    // 1. Doğruluk: zorluk + kişilik + momentum + rekabet (rubber-band)
    var accuracy = base.accuracy + persona.skill;
    accuracy += min(0.06, 0.02 * max(0, botStreak - 1)); // seri bonusu

    if (persona.competitive) {
      if (scoreGap > 150) accuracy += 0.05; // insan önde: bot zorlar
      if (scoreGap < -250) accuracy -= 0.03; // bot çok önde: biraz gevşer
      final isLast = questionIndex == totalQuestions - 1;
      if (isLast && scoreGap.abs() < 100) accuracy += 0.02; // son soru kararlılığı
    }
    accuracy = accuracy.clamp(0.2, 0.95).toDouble();

    // 2. Süre: zorluk aralığı + kişilik hızı + tereddüt
    var delay = base.minMs + random.nextInt(base.spanMs);
    delay = (delay * persona.pace).round();
    if (questionIndex == 0) delay += 2000; // ilk soru okuma payı
    if (lastAnswerWrong) delay += random.nextInt(1500); // yanlıştan sonra tereddüt
    if (persona.competitive && scoreGap > 150) {
      delay = (delay * 0.9).round(); // geride kalan bot hızlanır
    }
    delay = delay.clamp(4000, 23000);

    return BotTuning(accuracy, delay);
  }
}
