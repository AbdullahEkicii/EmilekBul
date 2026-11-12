import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/services/bot_persona.dart';

void main() {
  group('BotPersona', () {
    test('aynı uid her zaman aynı kişiliği üretir', () {
      final a = BotPersona.fromSeed('bot_123456');
      final b = BotPersona.fromSeed('bot_123456');
      expect(a.skill, b.skill);
      expect(a.pace, b.pace);
      expect(a.competitive, b.competitive);
    });

    test('değerler tanımlı aralıkların içinde kalır', () {
      for (var i = 0; i < 200; i++) {
        final p = BotPersona.fromSeed('bot_$i');
        expect(p.skill, inInclusiveRange(-0.04, 0.04));
        expect(p.pace, inInclusiveRange(0.85, 1.2));
        expect(p.chattiness, inInclusiveRange(0.2, 1.0));
      }
    });
  });

  group('BotDifficultyCurve', () {
    const persona = BotPersona(
      skill: 0,
      pace: 1,
      chattiness: 0.5,
      competitive: false,
    );

    BotTuning decide({
      String difficulty = 'Orta',
      int streak = 0,
      int gap = 0,
      int index = 1,
      bool wrong = false,
      BotPersona p = persona,
    }) {
      return BotDifficultyCurve.decide(
        difficulty: difficulty,
        persona: p,
        botStreak: streak,
        scoreGap: gap,
        questionIndex: index,
        totalQuestions: 5,
        lastAnswerWrong: wrong,
        random: Random(7),
      );
    }

    test('zorluk arttıkça doğruluk düşer', () {
      final easy = decide(difficulty: 'Kolay').accuracy;
      final medium = decide(difficulty: 'Orta').accuracy;
      final hard = decide(difficulty: 'Zor').accuracy;
      final impossible = decide(difficulty: 'İmkansız').accuracy;
      expect(easy, greaterThan(medium));
      expect(medium, greaterThan(hard));
      expect(hard, greaterThan(impossible));
    });

    test('seri doğruluğu artırır ama bonus sınırlıdır', () {
      final base = decide().accuracy;
      final hot = decide(streak: 2).accuracy;
      final onFire = decide(streak: 20).accuracy;
      expect(hot, greaterThan(base));
      expect(onFire - base, lessThanOrEqualTo(0.06 + 1e-9));
    });

    test('rekabetçi bot insan öndeyken zorlar, çok öndeyken gevşer', () {
      const rival = BotPersona(skill: 0, pace: 1, chattiness: 0.5, competitive: true);
      final neutral = decide(p: rival, gap: 0).accuracy;
      final behind = decide(p: rival, gap: 300).accuracy;
      final ahead = decide(p: rival, gap: -400).accuracy;
      expect(behind, greaterThan(neutral));
      expect(ahead, lessThan(neutral));
    });

    test('süre her zaman 4-23 sn aralığında kalır', () {
      for (final d in ['Kolay', 'Orta', 'Zor', 'İmkansız']) {
        for (var i = 0; i < 50; i++) {
          final t = BotDifficultyCurve.decide(
            difficulty: d,
            persona: const BotPersona(skill: 0.04, pace: 1.2, chattiness: 1, competitive: false),
            botStreak: 0,
            scoreGap: 0,
            questionIndex: i % 5,
            totalQuestions: 5,
            lastAnswerWrong: true,
            random: Random(i),
          );
          expect(t.delayMs, inInclusiveRange(4000, 23000));
          expect(t.accuracy, inInclusiveRange(0.2, 0.95));
        }
      }
    });
  });
}
