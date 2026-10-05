import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_constants.dart';

/// Reklam SDK'sının tek giriş noktası: önce (AB/AEA/UK için) UMP onay formu,
/// ardından MobileAds başlatılır. Tüm reklam yüklemeleri [ready]'yi bekler.
class AdsService {
  static final Completer<bool> _ready = Completer<bool>();
  static bool _started = false;

  /// Reklam istenebilir hale geldiğinde true ile tamamlanır.
  static Future<bool> get ready => _ready.future;

  static bool get isSupportedPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (_started) return;
    _started = true;
    if (!AdConstants.adsEnabled || !isSupportedPlatform) {
      _ready.complete(false);
      return;
    }
    try {
      await _gatherConsent();
    } catch (e) {
      debugPrint('AdsService consent error: $e');
    }
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdsService MobileAds init error: $e');
    }
    // Onay reddedilse bile canRequestAds sınırlı (non-personalized) reklama izin verebilir.
    bool canRequest = true;
    try {
      canRequest = await ConsentInformation.instance.canRequestAds();
    } catch (_) {}
    if (!_ready.isCompleted) _ready.complete(canRequest);
  }

  static Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('Consent form error: ${error.message}');
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError error) {
        debugPrint('Consent info update error: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// Hesap ekranında "Gizlilik seçenekleri" girişi gösterilmeli mi?
  static Future<bool> isPrivacyOptionsRequired() async {
    if (!isSupportedPlatform) return false;
    try {
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (error != null) debugPrint('Privacy options error: ${error.message}');
      });
    } catch (e) {
      debugPrint('Privacy options error: $e');
    }
  }
}
