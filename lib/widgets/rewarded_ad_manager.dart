import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/ad_constants.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';

class RewardedAdManager {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  bool get isReady => _rewardedAd != null;

  static const String _watchCountKey = 'rewarded_ad_watch_count';
  static const String _lastWatchTimeKey = 'rewarded_ad_last_watch_time';

  static const int tenMinutesMs = 10 * 60 * 1000;
  static const int oneHourMs = 60 * 60 * 1000;
  static const int sixHoursMs = 6 * 60 * 60 * 1000;

  /// Kalan bekleme süresini döner. Duration.zero ise izlenebilir.
  static Future<Duration> getRemainingCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt(_lastWatchTimeKey) ?? 0;
      var watchCount = prefs.getInt(_watchCountKey) ?? 0;

      if (lastWatchTime == 0) return Duration.zero;

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastWatchTime;

      // 6 saat geçmişse sayaç komple sıfırlanır ve en başa döner
      if (elapsed >= sixHoursMs) {
        await prefs.setInt(_watchCountKey, 0);
        return Duration.zero;
      }

      int requiredCooldownMs = 0;
      if (watchCount == 1) {
        requiredCooldownMs = tenMinutesMs; // 1. izlemeden sonra 10 dk
      } else if (watchCount >= 2) {
        requiredCooldownMs = oneHourMs; // 2. ve sonraki izlemelerden sonra 1 saat
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

  void showAd({required VoidCallback onRewarded}) {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (_) => AnalyticsService.logAdImpression(format: 'rewarded', placement: 'reward'),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
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
