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
    _simulateNextQuestion(0, 0, 0, []);
  }

  void _simulateNextQuestion(int index, int currentScore, int currentCombo, List<int?> answers) {
    if (_isCancelled) return;

    final questions = room.questions;
    if (index >= questions.length) {
      _finishBot(currentScore, answers);
      return;
    }

    final question = questions[index];
    final difficulty = room.config.difficulty;

    // Gerçekçi insan okuma ve düşünme süreleri (Her soru 7-20 sn aralığında çözülür)
    int delayMs;
    double accuracyChance;
    final int initialBuffer = (index == 0) ? 2000 : 0;

    final diffLower = difficulty.toLowerCase().trim();
    switch (diffLower) {
      case 'kolay':
      case 'easy':
        // Kolay: Ortalama 5'te 4 doğru (bazen 5/5, bazen 3/5) -> %75 - %88
        accuracyChance = 0.75 + (_random.nextDouble() * 0.13);
        delayMs = 7000 + initialBuffer + _random.nextInt(6000); // 7.0s - 13.0s (+2s ilk soru)
        break;
      case 'zor':
      case 'hard':
        // Zor: Ortalama 2.5 - 2.75 doğru (5'te 2 ya da 3 doğru) -> %48 - %58
        accuracyChance = 0.48 + (_random.nextDouble() * 0.10);
        delayMs = 13000 + initialBuffer + _random.nextInt(8000); // 13.0s - 21.0s (+2s ilk soru)
        break;
      case 'imkansız':
      case 'imkansiz':
      case 'impossible':
        // İmkansız: Ortalama 1.75 - 2 doğru (5'te 1 ya da 2 doğru) -> %33 - %42
        accuracyChance = 0.33 + (_random.nextDouble() * 0.09);
        delayMs = 15000 + initialBuffer + _random.nextInt(8000); // 15.0s - 23.0s (+2s ilk soru)
        break;
      case 'orta':
      case 'medium':
      default:
        // Orta: Ortalama 3.5 - 4 doğru -> %68 - %80
        accuracyChance = 0.68 + (_random.nextDouble() * 0.12);
        delayMs = 10000 + initialBuffer + _random.nextInt(8000); // 10.0s - 18.0s (+2s ilk soru)
        break;
    }

    // Maksimum 24 saniye ile sınırla (Süre aşımı olmaması için)
    delayMs = min(delayMs, 24000);

    _stepTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_isCancelled) return;

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
      int nextCombo = currentCombo;
      if (isCorrect) {
        nextCombo++;
        // Hızlı doğru cevap için hız bonuslu maç içi puanlama:
        // Taban 50 puan + (Kalan saniye * 4) + Kombo bonusu
        final remainingSec = max(0, 25 - (delayMs ~/ 1000));
        final speedBonus = remainingSec * 4;
        final comboBonus = (nextCombo > 1 ? (nextCombo * 10) : 0);
        newScore += 50 + speedBonus + comboBonus;
      } else {
        nextCombo = 0;
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
        if (isLast) {
          DuelService.resolveDuelResult(roomCode);
        }
      } catch (e) {
        debugPrint('Bot progress submit error: $e');
      }

      if (!isLast && !_isCancelled) {
        _simulateNextQuestion(index + 1, newScore, nextCombo, updatedAnswers);
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
