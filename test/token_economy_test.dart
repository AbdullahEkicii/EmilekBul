import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/services/token_economy.dart';

void main() {
  group('TokenEconomy harcamaları', () {
    test('jokerler test girişinden ucuz, düello girişi jokerden pahalı', () {
      expect(TokenEconomy.jokerCost, lessThan(TokenEconomy.quizEntryCost));
      expect(TokenEconomy.jokerSkipCost, greaterThan(TokenEconomy.jokerCost));
      expect(TokenEconomy.duelEntryCost, greaterThan(TokenEconomy.jokerCost));
    });

    test('tüm harcama miktarları pozitif', () {
      for (final v in [
        TokenEconomy.quizEntryCost,
        TokenEconomy.jokerCost,
        TokenEconomy.jokerSkipCost,
        TokenEconomy.duelEntryCost,
      ]) {
        expect(v, greaterThan(0));
      }
    });

    test('sıkılaştırılmış ekonomi jeton kıtlığını korur', () {
      expect(TokenEconomy.offlineQuizReward, lessThan(TokenEconomy.quizEntryCost));
      expect(TokenEconomy.dailyRewardAmount, lessThan(TokenEconomy.duelEntryCost));
      expect(TokenEconomy.miniGamePayoutMultiplier, lessThan(2.0));
      expect(TokenEconomy.arenaStakes, [25, 50, 100]);
    });
  });

  group('TokenEconomy kazanımları', () {
    test('davet edenin ödülü davet edilenden düşük (şişirme önlenir)', () {
      expect(TokenEconomy.referrerReward, lessThan(TokenEconomy.referralInviteeReward));
    });

    test('davet ödülü üst sınırı pozitif', () {
      expect(TokenEconomy.referrerRewardCap, greaterThan(0));
    });

    test('başlangıç bakiyesi 0 ve hoşgeldin hediyesi 40 jeton', () {
      expect(TokenEconomy.startingTokens, 0);
      expect(TokenEconomy.welcomeBonus, 40);
      expect(TokenEconomy.dailyRewardAmount, lessThan(50));
    });

    test('reklam hedefi bonusu, tek reklam ödülünden büyük', () {
      expect(TokenEconomy.adGoalBonus, greaterThan(TokenEconomy.rewardedAdAmount));
    });
  });

  group('adGoalReady', () {
    test('hedefe ulaşılmadan bonus verilmez', () {
      expect(
        TokenEconomy.adGoalReady(
            watchedToday: TokenEconomy.adGoalCount - 1, claimedToday: false),
        isFalse,
      );
    });

    test('hedefe ulaşılınca bir kez verilir', () {
      expect(
        TokenEconomy.adGoalReady(
            watchedToday: TokenEconomy.adGoalCount, claimedToday: false),
        isTrue,
      );
      expect(
        TokenEconomy.adGoalReady(
            watchedToday: TokenEconomy.adGoalCount, claimedToday: true),
        isFalse,
      );
    });
  });

  group('offlinePerformanceBonus', () {
    test('kusursuz, yüksek ve orta doğruluk oranlarına doğru bonus verir', () {
      expect(TokenEconomy.offlinePerformanceBonus(score: 5, totalQuestions: 5), 15);
      expect(TokenEconomy.offlinePerformanceBonus(score: 4, totalQuestions: 5), 8);
      expect(TokenEconomy.offlinePerformanceBonus(score: 3, totalQuestions: 5), 4);
      expect(TokenEconomy.offlinePerformanceBonus(score: 2, totalQuestions: 5), 0);
      expect(TokenEconomy.offlinePerformanceBonus(score: 0, totalQuestions: 5), 0);
      expect(TokenEconomy.offlinePerformanceBonus(score: 5, totalQuestions: 0), 0);
    });
  });
}
