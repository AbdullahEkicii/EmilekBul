import 'package:flutter/foundation.dart';

class AdConstants {
  static const bool adsEnabled = true;

  // Banner Reklam Kimliği (Banner Ad Unit ID)
  static const String androidBannerAdUnitId = 'ca-app-pub-2034009761866400/1717631727';
  static const String iosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

  // Native Reklam Kimliği (Native Ad Unit ID)
  static const String androidNativeAdUnitId = 'ca-app-pub-2034009761866400/9537477650';
  static const String iosNativeAdUnitId = 'ca-app-pub-3940256099942544/3986624511';

  // Ödüllü Reklam Kimliği (Rewarded Ad Unit ID)
  static const String androidRewardedAdUnitId = 'ca-app-pub-2034009761866400/8514657130';
  static const String iosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  // AdMob Standart Test Kimlikleri (Debug Modunda Hesabın Banlanmaması İçin)
  static const String testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testAndroidNativeId = 'ca-app-pub-3940256099942544/2247696110';
  static const String testAndroidRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  /// Banner Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kDebugMode ? testAndroidBannerId : androidBannerAdUnitId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosBannerAdUnitId;
    }
    return androidBannerAdUnitId;
  }

  /// Native Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get nativeAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kDebugMode ? testAndroidNativeId : androidNativeAdUnitId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosNativeAdUnitId;
    }
    return androidNativeAdUnitId;
  }

  /// Rewarded Ad Unit ID (Debug modda test ID, Release modda gerçek ID döner)
  static String get rewardedAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kDebugMode ? testAndroidRewardedId : androidRewardedAdUnitId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosRewardedAdUnitId;
    }
    return androidRewardedAdUnitId;
  }
}
