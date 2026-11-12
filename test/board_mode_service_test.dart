import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/services/board_mode_service.dart';

void main() {
  group('buildBoard', () {
    test('has 9 tiles with 3 of each multiplier (1x, 2x, 3x)', () {
      for (var seed = 0; seed < 50; seed++) {
        final board = BoardModeService.buildBoard(random: Random(seed));
        expect(board.length, BoardModeService.tileCount);
        expect(board.where((m) => m == 3).length, 3);
        expect(board.where((m) => m == 2).length, 3);
        expect(board.where((m) => m == 1).length, 3);
      }
    });

    test('is shuffled (different seeds produce different orders)', () {
      final boards = {
        for (var seed = 0; seed < 20; seed++)
          BoardModeService.buildBoard(random: Random(seed)).join(','),
      };
      expect(boards.length, greaterThan(1));
    });
  });

  group('scoreQuestion', () {
    test('correct answer gives base points times multiplier', () {
      expect(BoardModeService.scoreQuestion(correct: true, multiplier: 1), 100);
      expect(BoardModeService.scoreQuestion(correct: true, multiplier: 2), 200);
      expect(BoardModeService.scoreQuestion(correct: true, multiplier: 3), 300);
    });

    test('wrong answer gives 0 regardless of multiplier', () {
      for (final m in BoardModeService.multipliers) {
        expect(BoardModeService.scoreQuestion(correct: false, multiplier: m), 0);
      }
    });
  });

  group('isBoardComplete', () {
    test('is false before 9 resolved tiles and true at 9', () {
      expect(BoardModeService.isBoardComplete(0), isFalse);
      expect(BoardModeService.isBoardComplete(8), isFalse);
      expect(BoardModeService.isBoardComplete(9), isTrue);
    });
  });

  group('score bounds and best', () {
    test('max possible score is 1800 (3 * (300 + 200 + 100))', () {
      expect(BoardModeService.maxPossibleScore, 1800);
    });

    test('bestScore keeps the higher value', () {
      expect(BoardModeService.bestScore(500, 300), 500);
      expect(BoardModeService.bestScore(300, 500), 500);
      expect(BoardModeService.bestScore(0, 0), 0);
    });
  });
}
