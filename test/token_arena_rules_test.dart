import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/services/token_arena_rules.dart';
import 'package:emilekbul/services/token_economy.dart';

void main() {
  group('Yüksek-Düşük', () {
    test('doğru yön tahmini kazandırır', () {
      expect(TokenArenaRules.hiLoGuessCorrect(current: 5, next: 9, guessHigher: true), isTrue);
      expect(TokenArenaRules.hiLoGuessCorrect(current: 5, next: 2, guessHigher: false), isTrue);
    });

    test('yanlış yön ve eşitlik kaybettirir', () {
      expect(TokenArenaRules.hiLoGuessCorrect(current: 5, next: 2, guessHigher: true), isFalse);
      expect(TokenArenaRules.hiLoGuessCorrect(current: 7, next: 7, guessHigher: true), isFalse);
      expect(TokenArenaRules.hiLoGuessCorrect(current: 7, next: 7, guessHigher: false), isFalse);
    });

    test('kart değerleri 1-13 aralığında', () {
      final r = Random(1);
      for (var i = 0; i < 300; i++) {
        expect(TokenArenaRules.drawCard(r), inInclusiveRange(1, 13));
      }
    });
  });

  group('Hafıza dizisi', () {
    test('dizi doğru uzunluk ve renk aralığında', () {
      final seq = TokenArenaRules.buildSequence(Random(3));
      expect(seq.length, TokenArenaRules.memoryLength);
      for (final c in seq) {
        expect(c, inInclusiveRange(0, TokenArenaRules.memoryColors - 1));
      }
    });

    test('yalnızca sıradaki doğru renk kabul edilir', () {
      const seq = [0, 2, 1];
      expect(TokenArenaRules.memoryTapCorrect(seq, 0, 0), isTrue);
      expect(TokenArenaRules.memoryTapCorrect(seq, 1, 0), isFalse);
      expect(TokenArenaRules.memoryTapCorrect(seq, 5, 0), isFalse);
    });
  });

  group('Refleks', () {
    test('kazanma ve kaybetme eşikleri', () {
      expect(TokenArenaRules.reflexWon(TokenArenaRules.reflexHitsNeeded - 1), isFalse);
      expect(TokenArenaRules.reflexWon(TokenArenaRules.reflexHitsNeeded), isTrue);
      expect(TokenArenaRules.reflexLost(TokenArenaRules.reflexMaxMisses), isFalse);
      expect(TokenArenaRules.reflexLost(TokenArenaRules.reflexMaxMisses + 1), isTrue);
    });
  });

  group('Ödül', () {
    test('kazanınca bahis iki katına çıkar', () {
      expect(TokenArenaRules.payout(TokenEconomy.miniGameStake),
          TokenEconomy.miniGameStake * 2);
    });
  });
}
