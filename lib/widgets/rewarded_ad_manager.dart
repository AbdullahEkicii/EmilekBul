import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdManager {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  void loadAd({required VoidCallback onAdLoaded}) {
    if (_isLoading) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId:
          'ca-app-pub-3940256099942544/5224354917', // Gerçek ID ile değiştir
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
        },
      ),
    );
  }

  void showAd({required VoidCallback onRewarded}) {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
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
