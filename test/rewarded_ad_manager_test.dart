import 'package:flutter_test/flutter_test.dart';
import 'package:emilekbul/widgets/rewarded_ad_manager.dart';

void main() {
  group('RewardedAdManager.calculateCooldown', () {
    test('ilk izleme öncesi veya reset süresi dolunca bekleme yoktur', () {
      expect(
        RewardedAdManager.calculateCooldown(
          watchCount: 0,
          elapsedMs: 1000,
          isNewUser: false,
          cooldown1Seconds: 60,
          cooldown2Seconds: 300,
          resetHours: 4,
        ),
        Duration.zero,
      );
      expect(
        RewardedAdManager.calculateCooldown(
          watchCount: 3,
          elapsedMs: 4 * 60 * 60 * 1000,
          isNewUser: false,
          cooldown1Seconds: 60,
          cooldown2Seconds: 300,
          resetHours: 4,
        ),
        Duration.zero,
      );
    });

    test('1. ve 2.+ izleme sonrası soğuma sürelerini uygular', () {
      final rem1 = RewardedAdManager.calculateCooldown(
        watchCount: 1,
        elapsedMs: 20 * 1000,
        isNewUser: false,
        cooldown1Seconds: 60,
        cooldown2Seconds: 300,
        resetHours: 4,
      );
      expect(rem1.inSeconds, 40);

      final rem2 = RewardedAdManager.calculateCooldown(
        watchCount: 2,
        elapsedMs: 100 * 1000,
        isNewUser: false,
        cooldown1Seconds: 60,
        cooldown2Seconds: 300,
        resetHours: 4,
      );
      expect(rem2.inSeconds, 200);
    });

    test('yeni kullanıcılar için soğuma yarıya/birinci kademeye iner', () {
      final remNew1 = RewardedAdManager.calculateCooldown(
        watchCount: 1,
        elapsedMs: 10 * 1000,
        isNewUser: true,
        cooldown1Seconds: 60,
        cooldown2Seconds: 300,
        resetHours: 4,
      );
      expect(remNew1.inSeconds, 20);
    });
  });
}
