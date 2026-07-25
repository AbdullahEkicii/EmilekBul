import 'package:games_services/games_services.dart';

class GameService {
  static final GameService _instance = GameService._internal();

  factory GameService() {
    return _instance;
  }

  GameService._internal();

  Future<bool> signIn() async {
    try {
      await GamesServices.signIn();
      print("Game Service: Signed in successfully");
      return true;
    } catch (e) {
      print("Game Service: Error signing in: $e");
      return false;
    }
  }

  Future<void> submitScore(
      {required String leaderboardId, required int score}) async {
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: leaderboardId,
          value: score,
        ),
      );
      print("Game Service: Score submitted: $score");
    } catch (e) {
      print("Game Service: Error submitting score: $e");
    }
  }

  Future<String?> getPlayerID() async {
    try {
      return await GamesServices.getPlayerID();
    } catch (e) {
      print("Game Service: Error getting player ID: $e");
      return null;
    }
  }

  Future<String?> getPlayerName() async {
    try {
      return await GamesServices.getPlayerName();
    } catch (e) {
      print("Game Service: Error getting player name: $e");
      return null;
    }
  }
}
