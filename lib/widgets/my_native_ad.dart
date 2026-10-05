import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../constants/ad_constants.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';

/// Eski native reklam yerleşimlerinde gösterilen inline adaptif banner.
/// Yükseklik [height] ile sınırlanır (kırpılma olmaz); yenileme AdMob konsolundaki
/// otomatik yenileme ile yapılır.
class MyNativeAd extends StatefulWidget {
  final double height;
  final double width;

  static bool get adsEnabled => AdConstants.adsEnabled;

  const MyNativeAd({
    super.key,
    this.height = 100,
    this.width = double.infinity,
  });

  @override
  State<MyNativeAd> createState() => _MyNativeAdState();
}

class _MyNativeAdState extends State<MyNativeAd> {
  BannerAd? _bannerAd;
  AdSize? _loadedSize;
  bool _isLoading = false;
  bool _isVisible = false;
  int _failCount = 0;
  int? _slotWidth;
  Timer? _retryTimer;
  late final Key _visibilityKey = UniqueKey();

  void _onVisibilityChanged(VisibilityInfo info) {
    _isVisible = info.visibleFraction > 0.05;
    if (_isVisible) _loadIfNeeded();
  }

  Future<void> _loadIfNeeded() async {
    if (!MyNativeAd.adsEnabled || !AdsService.isSupportedPlatform) return;
    if (_bannerAd != null || _isLoading || _retryTimer != null) return;
    final width = _slotWidth;
    if (width == null || width <= 0) return;
    _isLoading = true;

    final canRequestAds = await AdsService.ready;
    if (!mounted || !canRequestAds) {
      _isLoading = false;
      return;
    }

    // Önce standart anchored adaptif boyut (telefonda ~50-60dp); alana sığmazsa yüksekliği sınırlı inline boyut.
    final anchored = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) {
      _isLoading = false;
      return;
    }
    final AdSize requestSize = (anchored != null && anchored.height <= widget.height)
        ? anchored
        : AdSize.getInlineAdaptiveBannerAdSize(width, widget.height.floor());

    final ad = BannerAd(
      adUnitId: AdConstants.nativeBannerAdUnitId,
      size: requestSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final banner = ad as BannerAd;
          final platformSize = await banner.getPlatformAdSize();
          if (!mounted) {
            banner.dispose();
            return;
          }
          setState(() {
            _bannerAd = banner;
            _loadedSize = platformSize ?? banner.size;
            _isLoading = false;
            _failCount = 0;
          });
        },
        onAdImpression: (_) => AnalyticsService.logAdImpression(format: 'banner', placement: 'inline'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Inline banner failed to load: $error');
          ad.dispose();
          _isLoading = false;
          _failCount++;
          _scheduleRetry();
        },
      ),
    );
    ad.load();
  }

  void _scheduleRetry() {
    if (!mounted) return;
    final delay = Duration(seconds: (30 * _failCount).clamp(30, 300));
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (mounted && _isVisible) _loadIfNeeded();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MyNativeAd.adsEnabled) return const SizedBox.shrink();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          _slotWidth = available.floor();

          final ad = _bannerAd;
          final size = _loadedSize;
          return VisibilityDetector(
            key: _visibilityKey,
            onVisibilityChanged: _onVisibilityChanged,
            child: ad != null && size != null
                ? Center(
                    child: SizedBox(
                      width: size.width.toDouble(),
                      height: size.height.toDouble(),
                      child: AdWidget(key: ObjectKey(ad), ad: ad),
                    ),
                  )
                : const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
