import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Uzaktan ayarlanabilir bayraklar (Firebase Remote Config).
/// init() açılışı asla bloklamaz; başarısızlıkta varsayılanlar döner.
class RemoteFlags {
  static const int _defFreeTests = 3;
  static const int _defEveryN = 3;
  static const int _defMinIntervalSeconds = 120;
  static const int _defLoadingMinWait = 1;
  static const int _defGoalTarget = 3;
  static const int _defChestHours = 6;
  static const int _defChestMin = 10;
  static const int _defChestMax = 20;
  static const int _defGoalChestMin = 30;
  static const int _defGoalChestMax = 60;
  static const int _defAdGraceDays = 2;
  static const int _defAdGraceTests = 3;
  static const int _defRewardedCooldown1Sec = 60;
  static const int _defRewardedCooldown2Sec = 300;
  static const int _defRewardedResetHours = 4;

  static const _kFreeTests = 'interstitial_free_tests';
  static const _kEveryN = 'interstitial_every_n';
  static const _kMinInterval = 'interstitial_min_interval_seconds';
  static const _kLoadingMinWait = 'loading_min_wait_seconds';
  static const _kGoalTarget = 'daily_goal_target';
  static const _kChestHours = 'chest_interval_hours';
  static const _kChestMin = 'chest_min_tokens';
  static const _kChestMax = 'chest_max_tokens';
  static const _kGoalChestMin = 'goal_chest_min_tokens';
  static const _kGoalChestMax = 'goal_chest_max_tokens';
  static const _kAdGraceDays = 'ad_grace_days';
  static const _kAdGraceTests = 'ad_grace_tests';
  static const _kRewardedCooldown1 = 'rewarded_cooldown_1_seconds';
  static const _kRewardedCooldown2 = 'rewarded_cooldown_2_seconds';
  static const _kRewardedResetHours = 'rewarded_reset_hours';
  static const _kAiProxyUrl = 'ai_proxy_url';
  static const _kThemedEventJson = 'themed_event_json';

  static FirebaseRemoteConfig? _rc;

  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 3),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 6),
      ));
      await rc.setDefaults(const {
        _kFreeTests: _defFreeTests,
        _kEveryN: _defEveryN,
        _kMinInterval: _defMinIntervalSeconds,
        _kLoadingMinWait: _defLoadingMinWait,
        _kGoalTarget: _defGoalTarget,
        _kChestHours: _defChestHours,
        _kChestMin: _defChestMin,
        _kChestMax: _defChestMax,
        _kGoalChestMin: _defGoalChestMin,
        _kGoalChestMax: _defGoalChestMax,
        _kAdGraceDays: _defAdGraceDays,
        _kAdGraceTests: _defAdGraceTests,
        _kRewardedCooldown1: _defRewardedCooldown1Sec,
        _kRewardedCooldown2: _defRewardedCooldown2Sec,
        _kRewardedResetHours: _defRewardedResetHours,
        _kAiProxyUrl: '',
        _kThemedEventJson: '',
      });
      _rc = rc; // varsayılanlar yüklendi, getter'lar güvenle okunabilir
      await rc.fetchAndActivate().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('RemoteFlags init error: $e');
    }
  }

  static int _int(String key, int def, {int min = 0, int max = 1000000}) {
    try {
      final v = _rc?.getInt(key);
      if (v == null) return def;
      return v.clamp(min, max);
    } catch (_) {
      return def;
    }
  }

  static String _str(String key, String def) {
    try {
      final v = _rc?.getString(key);
      return (v == null || v.trim().isEmpty) ? def : v.trim();
    } catch (_) {
      return def;
    }
  }

  static int get interstitialFreeTests => _int(_kFreeTests, _defFreeTests, max: 100);
  static int get interstitialEveryN => _int(_kEveryN, _defEveryN, min: 1, max: 100);
  static int get interstitialMinIntervalSeconds =>
      _int(_kMinInterval, _defMinIntervalSeconds, max: 86400);
  static int get loadingMinWaitSeconds => _int(_kLoadingMinWait, _defLoadingMinWait, max: 10);

  // Günlük hedef ve sandık ekonomisi (Remote Config'ten ayarlanabilir; makul sınırlara kısılır)
  static int get dailyGoalTarget => _int(_kGoalTarget, _defGoalTarget, min: 1, max: 10);
  static int get chestIntervalHours => _int(_kChestHours, _defChestHours, min: 1, max: 24);
  static int get chestMinTokens => _int(_kChestMin, _defChestMin, min: 1, max: 200);
  static int get chestMaxTokens => _int(_kChestMax, _defChestMax, min: 1, max: 200);
  static int get goalChestMinTokens => _int(_kGoalChestMin, _defGoalChestMin, min: 1, max: 500);
  static int get goalChestMaxTokens => _int(_kGoalChestMax, _defGoalChestMax, min: 1, max: 500);

  // Reklam sessiz dönem ve ödüllü reklam soğuma ayarları
  static int get adGraceDays => _int(_kAdGraceDays, _defAdGraceDays, min: 0, max: 30);
  static int get adGraceTests => _int(_kAdGraceTests, _defAdGraceTests, min: 0, max: 50);
  static int get rewardedCooldown1Seconds =>
      _int(_kRewardedCooldown1, _defRewardedCooldown1Sec, min: 0, max: 3600);
  static int get rewardedCooldown2Seconds =>
      _int(_kRewardedCooldown2, _defRewardedCooldown2Sec, min: 0, max: 7200);
  static int get rewardedResetHours =>
      _int(_kRewardedResetHours, _defRewardedResetHours, min: 1, max: 24);

  // Güvenli AI proxy URL'si (Firebase Cloud Function); boşsa doğrudan istemci anahtarı kullanılır
  static String get aiProxyUrl => _str(_kAiProxyUrl, '');

  // Haftalık / süreli tematik etkinlik JSON verisi (Remote Config)
  static String get themedEventJson => _str(_kThemedEventJson, '');
}
