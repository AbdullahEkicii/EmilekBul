import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../constants/ad_constants.dart';
import '../services/ad_grace.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

/// Eski native reklam yerleşimlerinde Android (>= 90dp yükseklik) için gerçek
/// [NativeAd] şablonu ([NativeTemplateStyle]), diğer durumlarda veya yükleme hatasında
/// otomatik olarak inline adaptif [BannerAd] yedeği gösterir.
class MyNativeAd extends StatefulWidget {
  final double height;
  final double width;

  /// Yeni kullanıcı sessiz döneminde (AdGrace) banner gösterilsin mi? Varsayılan true (yalnızca geçiş reklamları ertelenir).
  final bool keepDuringGrace;

  static bool get adsEnabled => AdConstants.adsEnabled;

  const MyNativeAd({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.keepDuringGrace = true,
  });

  @override
  State<MyNativeAd> createState() => _MyNativeAdState();
}

class _MyNativeAdState extends State<MyNativeAd> {
  BannerAd? _bannerAd;
  NativeAd? _nativeAd;
  AdSize? _loadedSize;
  bool _isLoading = false;
  bool _isVisible = false;
  bool _suppressedByGrace = false;
  int _failCount = 0;
  int? _slotWidth;
  Timer? _retryTimer;
  Timer? _releaseTimer;
  late final Key _visibilityKey = UniqueKey();

  bool get _supportsNativeTemplate =>
      defaultTargetPlatform == TargetPlatform.android && widget.height >= 90;

  void _onVisibilityChanged(VisibilityInfo info) {
    _isVisible = info.visibleFraction > 0.05;
    if (_isVisible) {
      _releaseTimer?.cancel();
      _releaseTimer = null;
      _loadIfNeeded();
    } else if ((_bannerAd != null || _nativeAd != null) && _releaseTimer == null) {
      _releaseTimer = Timer(const Duration(seconds: 10), _releaseAds);
    }
  }

  void _releaseAds() {
    _releaseTimer = null;
    if (!mounted || _isVisible) return;
    final banner = _bannerAd;
    final native = _nativeAd;
    if (banner == null && native == null) return;
    setState(() {
      _bannerAd = null;
      _nativeAd = null;
      _loadedSize = null;
    });
    banner?.dispose();
    native?.dispose();
  }

  Future<void> _loadIfNeeded() async {
    if (!MyNativeAd.adsEnabled || !AdsService.isSupportedPlatform) return;
    if (_bannerAd != null || _nativeAd != null || _isLoading || _retryTimer != null) return;
    final width = _slotWidth;
    if (width == null || width <= 0) return;
    _isLoading = true;

    final canRequestAds = await AdsService.ready;
    final inGrace = await AdGrace.isActive();
    if (!mounted) {
      _isLoading = false;
      return;
    }
    if (!canRequestAds || (inGrace && !widget.keepDuringGrace)) {
      _isLoading = false;
      if (inGrace && !widget.keepDuringGrace && !_suppressedByGrace) {
        setState(() => _suppressedByGrace = true);
      }
      return;
    }

    if (_supportsNativeTemplate) {
      _loadNativeTemplate(width);
    } else {
      await _loadAdaptiveBanner(width);
    }
  }

  void _loadNativeTemplate(int width) {
    final ad = NativeAd(
      adUnitId: AdConstants.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: AppColors.surface,
        cornerRadius: AppRadius.button,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.accent,
          style: NativeTemplateFontStyle.bold,
          size: 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textPrimary,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textSecondary,
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textSecondary,
          style: NativeTemplateFontStyle.normal,
          size: 11,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoading = false;
            _failCount = 0;
          });
        },
        onAdImpression: (_) => AnalyticsService.logAdImpression(format: 'native', placement: 'inline'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native template failed, falling back to banner: $error');
          AnalyticsService.logAdLoadFailed(format: 'native', placement: 'inline', code: error.code);
          ad.dispose();
          if (mounted) {
            _loadAdaptiveBanner(width);
          } else {
            _isLoading = false;
          }
        },
      ),
    );
    ad.load();
  }

  Future<void> _loadAdaptiveBanner(int width) async {
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
          AnalyticsService.logAdLoadFailed(format: 'banner', placement: 'inline', code: error.code);
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
    if (_failCount >= 5) return;
    final delay = Duration(seconds: (30 * _failCount).clamp(30, 300));
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (mounted && _isVisible) _loadIfNeeded();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _releaseTimer?.cancel();
    _bannerAd?.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MyNativeAd.adsEnabled || _suppressedByGrace) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          _slotWidth = available.floor();

          final native = _nativeAd;
          final banner = _bannerAd;
          final size = _loadedSize;
          Widget child = const SizedBox.expand();
          if (native != null) {
            child = ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: AdWidget(key: ObjectKey(native), ad: native),
            );
          } else if (banner != null && size != null) {
            child = Center(
              child: SizedBox(
                width: size.width.toDouble(),
                height: size.height.toDouble(),
                child: AdWidget(key: ObjectKey(banner), ad: banner),
              ),
            );
          }

          return VisibilityDetector(
            key: _visibilityKey,
            onVisibilityChanged: _onVisibilityChanged,
            child: child,
          );
        },
      ),
    );
  }
}
