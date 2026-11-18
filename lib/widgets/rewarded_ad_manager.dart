import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/ad_constants.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/remote_flags.dart';
import '../services/token_service.dart';

/// Uygulama genelinde paylaşımlı önyükleme tamponlu (singleton pool) ödüllü reklam yöneticisi.
/// Önce standart [RewardedAd] yükler; dolum olmazsa [RewardedInterstitialAd] yedeğine düşer.
class RewardedAdManager {
  static RewardedAd? _sharedRewardedAd;
  static RewardedInterstitialAd? _sharedRewardedInterstitialAd;
  static bool _sharedLoading = false;
  static final List<(VoidCallback, VoidCallback?)> _pendingCallbacks = [];

  bool get isReady =>
      _sharedRewardedAd != null || _sharedRewardedInterstitialAd != null;

  static const String _watchCountKey = 'rewarded_ad_watch_count';
  static const String _lastWatchTimeKey = 'rewarded_ad_last_watch_time';
  static const String _firstOpenKey = 'rewarded_first_open_ms';
  static const int newUserDays = 3;

  /// Saf soğuma hesabı (birim test edilebilir).
  static Duration calculateCooldown({
    required int watchCount,
    required int elapsedMs,
    required bool isNewUser,
    required int cooldown1Seconds,
    required int cooldown2Seconds,
    required int resetHours,
  }) {
    final resetMs = resetHours * 60 * 60 * 1000;
    if (elapsedMs >= resetMs || watchCount <= 0) return Duration.zero;

    int requiredMs = 0;
    if (watchCount == 1) {
      requiredMs = (isNewUser ? (cooldown1Seconds ~/ 2) : cooldown1Seconds) * 1000;
    } else if (watchCount >= 2) {
      requiredMs = (isNewUser ? cooldown1Seconds : cooldown2Seconds) * 1000;
    }
    final remainingMs = requiredMs - elapsedMs;
    return remainingMs <= 0 ? Duration.zero : Duration(milliseconds: remainingMs);
  }

  /// Kalan bekleme süresini döner. Duration.zero ise izlenebilir.
  static Future<Duration> getRemainingCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt(_lastWatchTimeKey) ?? 0;
      final watchCount = prefs.getInt(_watchCountKey) ?? 0;

      final now = DateTime.now().millisecondsSinceEpoch;
      var firstOpen = prefs.getInt(_firstOpenKey) ?? 0;
      if (firstOpen == 0) {
        firstOpen = now;
        await prefs.setInt(_firstOpenKey, now);
      }

      if (lastWatchTime == 0) return Duration.zero;
      final elapsed = now - lastWatchTime;
      final resetHours = RemoteFlags.rewardedResetHours;
      if (elapsed >= resetHours * 60 * 60 * 1000) {
        await prefs.setInt(_watchCountKey, 0);
        return Duration.zero;
      }

      final isNewUser = now - firstOpen < newUserDays * 24 * 60 * 60 * 1000;
      return calculateCooldown(
        watchCount: watchCount,
        elapsedMs: elapsed,
        isNewUser: isNewUser,
        cooldown1Seconds: RemoteFlags.rewardedCooldown1Seconds,
        cooldown2Seconds: RemoteFlags.rewardedCooldown2Seconds,
        resetHours: resetHours,
      );
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Kullanıcı bir ödüllü reklam izlediğinde çağrılır ve frekans sayacını kaydeder.
  static Future<void> recordAdWatched() async {
    await TokenService.recordRewardedAdForGoal();
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastWatchTime = prefs.getInt(_lastWatchTimeKey) ?? 0;
      var watchCount = prefs.getInt(_watchCountKey) ?? 0;
      final resetMs = RemoteFlags.rewardedResetHours * 60 * 60 * 1000;

      if (now - lastWatchTime >= resetMs) {
        watchCount = 0;
      }

      watchCount++;
      await prefs.setInt(_watchCountKey, watchCount);
      await prefs.setInt(_lastWatchTimeKey, now);
    } catch (e) {
      debugPrint('Error recording ad watched: $e');
    }
  }

  /// Uygulama açılışında veya reklam kapandıktan sonra arka planda reklam hazırlar.
  static void warmUp() {
    _preloadShared();
  }

  static void _flushCallbacks({required bool success}) {
    final cbs = List<(VoidCallback, VoidCallback?)>.from(_pendingCallbacks);
    _pendingCallbacks.clear();
    for (final (onLoaded, onFailed) in cbs) {
      if (success) {
        onLoaded();
      } else {
        onFailed?.call();
      }
    }
  }

  static void _preloadShared() {
    if (!AdConstants.adsEnabled || !AdsService.isSupportedPlatform) {
      _flushCallbacks(success: false);
      return;
    }
    if (_sharedRewardedAd != null || _sharedRewardedInterstitialAd != null) {
      _flushCallbacks(success: true);
      return;
    }
    if (_sharedLoading) return;
    _sharedLoading = true;

    AdsService.ready.then((canRequestAds) {
      if (!canRequestAds) {
        _sharedLoading = false;
        _flushCallbacks(success: false);
        return;
      }
      RewardedAd.load(
        adUnitId: AdConstants.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _sharedRewardedAd = ad;
            _sharedLoading = false;
            _flushCallbacks(success: true);
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load, trying rewarded interstitial: $error');
            AnalyticsService.logAdLoadFailed(format: 'rewarded', placement: 'rewarded', code: error.code);
            _loadRewardedInterstitialFallback();
          },
        ),
      );
    });
  }

  static void _loadRewardedInterstitialFallback() {
    RewardedInterstitialAd.load(
      adUnitId: AdConstants.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _sharedRewardedInterstitialAd = ad;
          _sharedLoading = false;
          _flushCallbacks(success: true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded interstitial failed to load: $error');
          AnalyticsService.logAdLoadFailed(
            format: 'rewarded_interstitial',
            placement: 'rewarded',
            code: error.code,
          );
          _sharedLoading = false;
          _flushCallbacks(success: false);
        },
      ),
    );
  }

  void loadAd({required VoidCallback onAdLoaded, VoidCallback? onFailed}) {
    if (!AdsService.isSupportedPlatform || !AdConstants.adsEnabled) {
      onFailed?.call();
      return;
    }
    if (isReady) {
      onAdLoaded();
      return;
    }
    _pendingCallbacks.add((onAdLoaded, onFailed));
    _preloadShared();
  }

  /// Paylaşımlı tampon diğer ekranlar tarafından kullanılmaya devam ettiği için
  /// burada küresel reklamı kapatmıyoruz; sonraki ekranda anında hazır kalır.
  void dispose() {}

  /// [onDismissed] reklam kapandığında (ödül verilmiş olsun ya da olmasın) çağrılır.
  void showAd({required VoidCallback onRewarded, VoidCallback? onDismissed}) {
    final rewarded = _sharedRewardedAd;
    if (rewarded != null) {
      _sharedRewardedAd = null;
      rewarded.fullScreenContentCallback = FullScreenContentCallback(
        onAdImpression: (_) => AnalyticsService.logAdImpression(format: 'rewarded', placement: 'reward'),
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          warmUp();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          warmUp();
          onDismissed?.call();
        },
      );
      rewarded.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
          onRewarded();
        },
      );
      return;
    }

    final rewardedInterstitial = _sharedRewardedInterstitialAd;
    if (rewardedInterstitial != null) {
      _sharedRewardedInterstitialAd = null;
      rewardedInterstitial.fullScreenContentCallback = FullScreenContentCallback(
        onAdImpression: (_) => AnalyticsService.logAdImpression(
          format: 'rewarded_interstitial',
          placement: 'reward',
        ),
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          warmUp();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          warmUp();
          onDismissed?.call();
        },
      );
      rewardedInterstitial.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
          onRewarded();
        },
      );
      return;
    }

    warmUp();
    onDismissed?.call();
  }
}
