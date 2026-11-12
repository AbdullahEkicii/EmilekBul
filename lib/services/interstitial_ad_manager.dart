import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/ad_constants.dart';
import 'ad_grace.dart';
import 'ads_service.dart';
import 'analytics_service.dart';
import 'remote_flags.dart';

/// Test/düello bitişinde sonuç ekranından önce gösterilen geçiş reklamı.
/// Kural: tekli + düello toplam ilk [freeTests] testte gösterilmez, sonra her
/// [everyNTests] testte bir ve iki gösterim arasında en az [minInterval] geçer.
/// Değerler Remote Config'ten gelir (RemoteFlags); varsayılanlar: 6 / 3 / 180 sn.
class InterstitialAdManager {
  static int get freeTests => RemoteFlags.interstitialFreeTests;
  static int get everyNTests => RemoteFlags.interstitialEveryN;
  static Duration get minInterval => Duration(seconds: RemoteFlags.interstitialMinIntervalSeconds);

  static const String _countKey = 'ads_completed_tests';
  static const String _lastShownKey = 'ads_interstitial_last_shown';

  static InterstitialAd? _ad;
  static bool _loading = false;
  static int _retryAttempt = 0;

  /// Uygulama açılışında: eşiğe yaklaşan kullanıcı için reklamı önceden yükler.
  static Future<void> warmUp() async {
    // Düşük RAM'li cihazlarda önceden yükleme yapma; reklam ilk gösterimde on-demand yüklenir
    if (await _isLowMemoryDevice()) return;
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(_countKey) ?? 0) >= freeTests - 1) preload();
  }

  static Future<bool> _isLowMemoryDevice() async {
    try {
      if (!Platform.isAndroid) return false;
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.isLowRamDevice) return true;
      // physicalRamSize MB cinsinden; ~3 GB altı düşük kabul edilir
      return info.physicalRamSize > 0 && info.physicalRamSize < 3000;
    } catch (_) {
      return false;
    }
  }

  static Future<void> preload() async {
    if (_ad != null || _loading) return;
    if (!await AdsService.ready) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          _retryAttempt = 0;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          AnalyticsService.logAdLoadFailed(format: 'interstitial', placement: 'interstitial', code: error.code);
          _loading = false;
          _retryAttempt++;
          final delay = Duration(seconds: (30 * _retryAttempt).clamp(30, 300));
          Timer(delay, preload);
        },
      ),
    );
  }

  /// Bir test bittiğinde çağrılır. Reklam gösterilirse kapandıktan sonra,
  /// gösterilmezse hemen [onDone] çalışır. [source]: 'solo' veya 'duel'.
  static Future<void> onTestFinished({required String source, required VoidCallback onDone}) async {
    var called = false;
    void finish() {
      if (called) return;
      called = true;
      onDone();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, count);

      if (await AdGrace.isActive()) {
        finish();
        return;
      }

      final lastShown = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_lastShownKey) ?? 0);
      final dueByCount = count > freeTests && (count - freeTests) % everyNTests == 0;
      final dueByTime = DateTime.now().difference(lastShown) >= minInterval;
      final ad = _ad;

      if (!dueByCount || !dueByTime || ad == null) {
        if (count >= freeTests) preload();
        finish();
        return;
      }

      _ad = null;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
        },
        onAdImpression: (_) {
          AnalyticsService.logAdImpression(format: 'interstitial', placement: source);
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          preload();
          finish();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Interstitial failed to show: $error');
          ad.dispose();
          preload();
          finish();
        },
      );
      await ad.show();
    } catch (e) {
      debugPrint('InterstitialAdManager error: $e');
      finish();
    }
  }
}
