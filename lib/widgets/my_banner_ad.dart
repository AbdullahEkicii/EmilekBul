import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/ad_grace.dart';
import '../services/analytics_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../constants/ad_constants.dart';

class MyBannerAd extends StatefulWidget {
  final AdSize adSize;

  const MyBannerAd({
    super.key,
    this.adSize = AdSize.banner,
  });

  @override
  State<MyBannerAd> createState() => _MyBannerAdState();
}

class _MyBannerAdState extends State<MyBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _isVisible = false;
  late final Key _visibilityKey;

  @override
  void initState() {
    super.initState();
    _visibilityKey = UniqueKey();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final bool isVisibleNow = info.visibleFraction > 0.05;
    if (isVisibleNow != _isVisible) {
      _isVisible = isVisibleNow;
      if (_isVisible && !_isAdLoaded && !_isLoading) {
        _loadAd();
      }
    }
  }

  void _loadAd() {
    AdGrace.isActive().then((grace) {
      if (mounted && !grace) _startLoad();
    });
  }

  void _startLoad() {
    if (!AdConstants.adsEnabled) return;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    if (_isLoading || _isAdLoaded) return;
    _isLoading = true;

    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          AnalyticsService.logAdLoadFailed(format: 'banner', placement: 'banner', code: error.code);
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isAdLoaded = false;
              _isLoading = false;
            });
          }
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConstants.adsEnabled) {
      return const SizedBox.shrink();
    }

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: SizedBox(
        width: widget.adSize.width.toDouble(),
        height: widget.adSize.height.toDouble(),
        child: _isAdLoaded && _bannerAd != null
            ? AdWidget(ad: _bannerAd!)
            : const SizedBox.shrink(),
      ),
    );
  }
}

