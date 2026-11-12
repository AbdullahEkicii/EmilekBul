import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/duel_room_model.dart';
import 'bot_persona.dart';
import 'duel_service.dart';

/// Bot rakibin soru çözme simülasyonu.
/// Kararlar [BotDifficultyCurve] üzerinden verilir: zorluk, bot kişiliği,
/// seri (momentum) ve insan rakibin anlık skoru birlikte etkiler.
class BotQuizSimulator {
  final String roomCode;
  final DuelRoom room;
  final bool isHostBot;

  final Random _random = Random();
  late final BotPersona _persona;
  bool _isCancelled = false;
  Timer? _stepTimer;
  StreamSubscription<DuelRoom?>? _roomSub;
  final Stopwatch _stopwatch = Stopwatch();
  int _humanScore = 0;

  BotQuizSimulator({
    required this.roomCode,
    required this.room,
    required this.isHostBot,
  }) {
    final botUid = isHostBot ? room.host.uid : (room.guest?.uid ?? room.hostUid);
    _persona = BotPersona.fromSeed(botUid);
    _humanScore = (isHostBot ? room.guest?.score : room.host.score) ?? 0;
  }

  /// Botun Soru Çözme Simülasyonunu Başlat
  void start() {
    _isCancelled = false;
    _stopwatch.start();
    // Rakibin (insan) canlı skorunu izle: bot buna göre tempo ayarlar
    _roomSub = DuelService.streamRoom(roomCode).listen((latest) {
      final human = latest == null ? null : (isHostBot ? latest.guest : latest.host);
      if (human != null) _humanScore = human.score;
    });
    _simulateNextQuestion(0, 0, 0, [], false);
  }

  void _simulateNextQuestion(
    int index,
    int currentScore,
    int currentStreak,
    List<int?> answers,
    bool lastAnswerWrong,
  ) {
    if (_isCancelled) return;

    final questions = room.questions;
    if (index >= questions.length) {
      _finishBot(currentScore, answers);
      return;
    }

    final question = questions[index];
    final tuning = BotDifficultyCurve.decide(
      difficulty: room.config.difficulty,
      persona: _persona,
      botStreak: currentStreak,
      scoreGap: _humanScore - currentScore,
      questionIndex: index,
      totalQuestions: questions.length,
      lastAnswerWrong: lastAnswerWrong,
      random: _random,
    );
    final int delayMs = tuning.delayMs;

    _stepTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_isCancelled) return;

      final isCorrect = _random.nextDouble() < tuning.accuracy;
      int selectedAnswer;

      if (isCorrect) {
        selectedAnswer = question.correctIndex;
      } else {
        // Yanlış bir şık seç
        final wrongOptions = [0, 1, 2, 3]..remove(question.correctIndex);
        selectedAnswer = wrongOptions[_random.nextInt(wrongOptions.length)];
      }

      int newScore = currentScore;
      int nextStreak = currentStreak;
      if (isCorrect) {
        nextStreak++;
        // Hızlı doğru cevap için hız bonuslu maç içi puanlama:
        // Taban 50 puan + (Kalan saniye * 4) + Kombo bonusu
        final remainingSec = max(0, 25 - (delayMs ~/ 1000));
        final speedBonus = remainingSec * 4;
        final comboBonus = (nextStreak > 1 ? (nextStreak * 10) : 0);
        newScore += 50 + speedBonus + comboBonus;
      } else {
        nextStreak = 0;
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
        _simulateNextQuestion(
          index + 1,
          newScore,
          nextStreak,
          updatedAnswers,
          !isCorrect,
        );
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
    _roomSub?.cancel();
    _roomSub = null;
    _stopwatch.stop();
  }
}
