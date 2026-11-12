import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/ad_constants.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/token_service.dart';

class RewardedAdManager {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  bool get isReady => _rewardedAd != null;

  static const String _watchCountKey = 'rewarded_ad_watch_count';
  static const String _lastWatchTimeKey = 'rewarded_ad_last_watch_time';

  static const String _firstOpenKey = 'rewarded_first_open_ms';
  static const int twoMinutesMs = 2 * 60 * 1000;
  static const int newUserDays = 3;
  static const int tenMinutesMs = 10 * 60 * 1000;
  static const int oneHourMs = 60 * 60 * 1000;
  static const int sixHoursMs = 6 * 60 * 60 * 1000;

  /// Kalan bekleme süresini döner. Duration.zero ise izlenebilir.
  static Future<Duration> getRemainingCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt(_lastWatchTimeKey) ?? 0;
      var watchCount = prefs.getInt(_watchCountKey) ?? 0;

      final now = DateTime.now().millisecondsSinceEpoch;
      var firstOpen = prefs.getInt(_firstOpenKey) ?? 0;
      if (firstOpen == 0) {
        firstOpen = now;
        await prefs.setInt(_firstOpenKey, now);
      }

      if (lastWatchTime == 0) return Duration.zero;
      final elapsed = now - lastWatchTime;

      // 6 saat geçmişse sayaç komple sıfırlanır ve en başa döner
      if (elapsed >= sixHoursMs) {
        await prefs.setInt(_watchCountKey, 0);
        return Duration.zero;
      }

      // İlk 3 günde yeni kullanıcı için kısa bekleme: 2 dk / 10 dk
      final isNewUser = now - firstOpen < newUserDays * 24 * 60 * 60 * 1000;

      int requiredCooldownMs = 0;
      if (watchCount == 1) {
        requiredCooldownMs = isNewUser ? twoMinutesMs : tenMinutesMs; // 1. izlemeden sonra
      } else if (watchCount >= 2) {
        requiredCooldownMs = isNewUser ? tenMinutesMs : oneHourMs; // 2. ve sonrası
      }

      final remainingMs = requiredCooldownMs - elapsed;
      if (remainingMs <= 0) {
        return Duration.zero;
      }
      return Duration(milliseconds: remainingMs);
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Kullanıcı bir ödüllü reklam izlediğinde çağrılır ve frekans sayacını kaydeder
  static Future<void> recordAdWatched() async {
    await TokenService.recordRewardedAdForGoal();
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastWatchTime = prefs.getInt(_lastWatchTimeKey) ?? 0;
      var watchCount = prefs.getInt(_watchCountKey) ?? 0;

      if (now - lastWatchTime >= sixHoursMs) {
        watchCount = 0;
      }

      watchCount++;
      await prefs.setInt(_watchCountKey, watchCount);
      await prefs.setInt(_lastWatchTimeKey, now);
    } catch (e) {
      debugPrint('Error recording ad watched: $e');
    }
  }

  void loadAd({required VoidCallback onAdLoaded, VoidCallback? onFailed}) {
    if (_isLoading) return;
    if (!AdsService.isSupportedPlatform) {
      onFailed?.call();
      return;
    }
    if (_rewardedAd != null) {
      onAdLoaded();
      return;
    }
    _isLoading = true;

    AdsService.ready.then((canRequestAds) {
      if (!canRequestAds) {
        _isLoading = false;
        onFailed?.call();
        return;
      }
      RewardedAd.load(
        adUnitId: AdConstants.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoading = false;
            onAdLoaded();
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load: $error');
            AnalyticsService.logAdLoadFailed(format: 'rewarded', placement: 'rewarded', code: error.code);
            _isLoading = false;
            onFailed?.call();
          },
        ),
      );
    });
  }

  /// Gösterilmemiş yüklü reklamı serbest bırak (ekran dispose'unda çağrılır)
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  /// [onDismissed] reklam kapandığında (ödül verilmiş olsun ya da olmasın) çağrılır.
  void showAd({required VoidCallback onRewarded, VoidCallback? onDismissed}) {
    if (_rewardedAd == null) {
      onDismissed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (_) => AnalyticsService.logAdImpression(format: 'rewarded', placement: 'reward'),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        onDismissed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
        onRewarded(); // Kullanıcı ödül aldı
      },
    );
    _rewardedAd = null;
  }
}
