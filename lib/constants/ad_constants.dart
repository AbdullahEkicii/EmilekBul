import 'package:flutter/foundation.dart';

class AdConstants {
  static const bool adsEnabled = true;

  // Banner Reklam Kimliği (Banner Ad Unit ID)
  static const String androidBannerAdUnitId = 'ca-app-pub-2034009761866400/1717631727';
  static const String iosBannerAdUnitId = 'ca-app-pub-2034009761866400/8531530355';

  // Native Reklam Kimliği (Native Ad Unit ID) — artık kullanılmıyor, banner'a geçildi
  static const String androidNativeAdUnitId = 'ca-app-pub-2034009761866400/9537477650';
  static const String iosNativeAdUnitId = 'ca-app-pub-3940256099942544/3986624511';

  // Native yerine kullanılan banner reklam kimliği (eski native reklam yerleşimleri)
  static const String androidNativeBannerAdUnitId = 'ca-app-pub-2034009761866400/3083520339';
  static const String iosNativeBannerAdUnitId = 'ca-app-pub-2034009761866400/8531530355';

  // Ödüllü Reklam Kimliği (Rewarded Ad Unit ID)
  static const String androidRewardedAdUnitId = 'ca-app-pub-2034009761866400/8514657130';
  static const String iosRewardedAdUnitId = 'ca-app-pub-2034009761866400/9487399701';

  // Ödüllü Geçiş Reklamı Kimliği (Rewarded Interstitial Ad Unit ID)
  static const String androidRewardedInterstitialAdUnitId = 'ca-app-pub-3940256099942544/5354046379';
  static const String iosRewardedInterstitialAdUnitId = 'ca-app-pub-2034009761866400/3824009482';

  // Geçiş Reklamı Kimliği (Interstitial Ad Unit ID)
  static const String androidInterstitialAdUnitId = 'ca-app-pub-2034009761866400/4377235377';
  static const String iosInterstitialAdUnitId = 'ca-app-pub-2034009761866400/8148386972';

  // AdMob Standart Test Kimlikleri (Debug Modunda Hesabın Banlanmaması İçin)
  static const String testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testAndroidNativeId = 'ca-app-pub-3940256099942544/2247696110';
  static const String testAndroidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testAndroidRewardedInterstitialId = 'ca-app-pub-3940256099942544/5354046379';
  static const String testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  static const String testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const String testIosNativeId = 'ca-app-pub-3940256099942544/3986624511';
  static const String testIosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const String testIosRewardedInterstitialId = 'ca-app-pub-3940256099942544/6978759866';
  static const String testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  /// Banner Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kDebugMode ? testIosBannerId : iosBannerAdUnitId;
    }
    return kDebugMode ? testAndroidBannerId : androidBannerAdUnitId;
  }

  /// Native Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get nativeAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kDebugMode ? testIosNativeId : iosNativeAdUnitId;
    }
    return kDebugMode ? testAndroidNativeId : androidNativeAdUnitId;
  }

  /// Native yerine kullanılan Banner Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get nativeBannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kDebugMode ? testIosBannerId : iosNativeBannerAdUnitId;
    }
    return kDebugMode ? testAndroidBannerId : androidNativeBannerAdUnitId;
  }

  /// Interstitial Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get interstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kDebugMode ? testIosInterstitialId : iosInterstitialAdUnitId;
    }
    return kDebugMode ? testAndroidInterstitialId : androidInterstitialAdUnitId;
  }

  /// Rewarded Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get rewardedAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kDebugMode ? testIosRewardedId : iosRewardedAdUnitId;
    }
    return kDebugMode ? testAndroidRewardedId : androidRewardedAdUnitId;
  }

  /// Rewarded Interstitial Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get rewardedInterstitialAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kDebugMode
          ? testIosRewardedInterstitialId
          : iosRewardedInterstitialAdUnitId;
    }
    return kDebugMode
        ? testAndroidRewardedInterstitialId
        : androidRewardedInterstitialAdUnitId;
  }
}
