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
  });

  group('TokenEconomy kazanımları', () {
    test('davet edenin ödülü davet edilenden düşük (şişirme önlenir)', () {
      expect(TokenEconomy.referrerReward, lessThan(TokenEconomy.referralInviteeReward));
    });

    test('davet ödülü üst sınırı pozitif', () {
      expect(TokenEconomy.referrerRewardCap, greaterThan(0));
    });

    test('hoşgeldin ve günlük ödül eski değerlerin altında', () {
      expect(TokenEconomy.welcomeBonus, lessThan(100));
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
}
