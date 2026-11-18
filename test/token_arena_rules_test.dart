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

    test('kasa avantajı korunur (EV < 1.0)', () {
      expect(TokenArenaRules.hiLoExpectedValue(), lessThan(1.0));
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

    test('vuruş arttıkça süre penceresi daralır', () {
      expect(TokenArenaRules.reflexWindowMs(5), lessThan(TokenArenaRules.reflexWindowMs(0)));
    });
  });

  group('Mayınlı Kasa', () {
    test('12 hücrede tam 4 benzersiz mayın üretir', () {
      final mines = TokenArenaRules.generateMines(Random(7));
      expect(mines.length, TokenArenaRules.minesBombCount);
      for (final m in mines) {
        expect(m, inInclusiveRange(0, TokenArenaRules.minesTotalTiles - 1));
      }
    });

    test('tüm çekilme kademelerinde beklenen değer < 1.0 (kasa hep kazanır)', () {
      for (var step = 1; step <= TokenArenaRules.minesMaxSafePicks; step++) {
        expect(
          TokenArenaRules.minesExpectedValue(step),
          lessThan(1.0),
          reason: 'Step $step EV kasa lehine olmalı',
        );
      }
    });
  });

  group('Çarpan Ruleti', () {
    test('beklenen değer tam 0.80 (< 1.0 kasa avantajı)', () {
      expect(TokenArenaRules.wheelExpectedValue(), closeTo(0.80, 0.001));
    });

    test('dilim seçimi ve ödeme hesabı doğru', () {
      final r = Random(9);
      for (var i = 0; i < 100; i++) {
        expect(
          TokenArenaRules.spinWheelIndex(r),
          inInclusiveRange(0, TokenArenaRules.wheelMultipliers.length - 1),
        );
      }
      expect(TokenArenaRules.wheelPayout(100, 5), 350);
      expect(TokenArenaRules.wheelPayout(100, 0), 0);
    });
  });

  group('Ödül', () {
    test('kazanınca 1.8x kasa avantajlı ödeme yapılır', () {
      expect(TokenArenaRules.payout(TokenEconomy.miniGameStake),
          (TokenEconomy.miniGameStake * 1.8).floor());
      expect(TokenArenaRules.payout(25), 45);
      expect(TokenArenaRules.payout(100), 180);
    });
  });
}
