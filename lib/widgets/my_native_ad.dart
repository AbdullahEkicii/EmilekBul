import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_constants.dart';

class MyNativeAd extends StatefulWidget {
  final double height;
  final double width;
  final String factoryId;
  final int? refreshInterval; // seconds

  static bool get adsEnabled => AdConstants.adsEnabled;

  const MyNativeAd({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.factoryId = 'adFactorySmall',
    this.refreshInterval,
  });

  @override
  State<MyNativeAd> createState() => _MyNativeAdState();
}

class _MyNativeAdState extends State<MyNativeAd> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!MyNativeAd.adsEnabled) return;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final String adUnitId = AdConstants.nativeAdUnitId;

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _isAdLoaded = false;
            });
          }
        },
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MyNativeAd.adsEnabled || !_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}

