import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/duel_room_model.dart';
import 'duel_service.dart';

class BotQuizSimulator {
  final String roomCode;
  final DuelRoom room;
  final bool isHostBot;

  final Random _random = Random();
  bool _isCancelled = false;
  Timer? _stepTimer;
  final Stopwatch _stopwatch = Stopwatch();

  BotQuizSimulator({
    required this.roomCode,
    required this.room,
    required this.isHostBot,
  });

  /// Botun Soru Çözme Simülasyonunu Başlat
  void start() {
    _isCancelled = false;
    _stopwatch.start();
    _simulateNextQuestion(0, 0, []);
  }

  void _simulateNextQuestion(int index, int currentScore, List<int?> answers) {
    if (_isCancelled) return;

    final questions = room.questions;
    if (index >= questions.length) {
      _finishBot(currentScore, answers);
      return;
    }

    final question = questions[index];
    final difficulty = room.config.difficulty;

    // Gerçekçi düşünme süreleri ve insani doğruluk oranları
    int delayMs;
    double accuracyChance;
    switch (difficulty) {
      case 'Kolay':
        accuracyChance = 0.40 + (_random.nextDouble() * 0.12); // %40 - %52 (Yeni başlayanlar rahatça kazanır)
        delayMs = 3800 + _random.nextInt(4200); // 3.8s - 8.0s
        break;
      case 'Zor':
        accuracyChance = 0.68 + (_random.nextDouble() * 0.12); // %68 - %80
        delayMs = 2800 + _random.nextInt(3200); // 2.8s - 6.0s
        break;
      case 'Imkansız':
      case 'İmkansız':
        accuracyChance = 0.78 + (_random.nextDouble() * 0.10); // %78 - %88
        delayMs = 2200 + _random.nextInt(2800); // 2.2s - 5.0s
        break;
      default: // Orta
        accuracyChance = 0.55 + (_random.nextDouble() * 0.12); // %55 - %67 (Tatmin edici, dengeli rekabet)
        delayMs = 3200 + _random.nextInt(3800); // 3.2s - 7.0s
    }

    _stepTimer = Timer(Duration(milliseconds: delayMs), () async {

      final isCorrect = _random.nextDouble() < accuracyChance;
      int selectedAnswer;

      if (isCorrect) {
        selectedAnswer = question.correctIndex;
      } else {
        // Yanlış bir şık seç
        final wrongOptions = [0, 1, 2, 3]..remove(question.correctIndex);
        selectedAnswer = wrongOptions[_random.nextInt(wrongOptions.length)];
      }

      int newScore = currentScore;
      if (isCorrect) {
        // Hız bonuslu puanlama (10-15 puan)
        final timeBonus = max(1, (25 - (delayMs / 1000)).round());
        newScore += 10 + (timeBonus ~/ 5);
      }

      final updatedAnswers = List<int?>.from(answers)..add(selectedAnswer);
      final isLast = index == questions.length - 1;
      final totalElapsedMs = _stopwatch.elapsedMilliseconds;

      try {
        await DuelService.updatePlayerProgress(
          roomCode: roomCode,
          isHost: isHostBot,
          progress: index + 1,
          score: newScore,
          finished: isLast,
          finishTime: isLast ? totalElapsedMs : 0,
          userAnswers: updatedAnswers,
        );
      } catch (e) {
        debugPrint('Bot progress submit error: $e');
      }

      if (!isLast && !_isCancelled) {
        _simulateNextQuestion(index + 1, newScore, updatedAnswers);
      }
    });
  }

  void _finishBot(int finalScore, List<int?> answers) async {
    if (_isCancelled) return;
    final totalElapsedMs = _stopwatch.elapsedMilliseconds;

    try {
      await DuelService.updatePlayerProgress(
        roomCode: roomCode,
        isHost: isHostBot,
        progress: room.questions.length,
        score: finalScore,
        finished: true,
        finishTime: totalElapsedMs,
        userAnswers: answers,
      );
    } catch (_) {}
  }

  /// Simülasyonu Durdur (Sayfa kapandığında)
  void cancel() {
    _isCancelled = true;
    _stepTimer?.cancel();
    _stopwatch.stop();
  }
}
