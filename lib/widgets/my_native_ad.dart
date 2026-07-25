import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class MyNativeAd extends StatefulWidget {
  final double height;
  final double width;
  final String factoryId;
  final int? refreshInterval; // seconds

  const MyNativeAd({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.factoryId = 'adFactoryExample',
    this.refreshInterval,
  });

  @override
  State<MyNativeAd> createState() => _MyNativeAdState();
}

class _MyNativeAdState extends State<MyNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _isDisposed = false;
  @override
  void initState() {
    super.initState();
    _loadAd();
  }



  void _loadAd() {
    if (_isDisposed) return;

    final newAd = NativeAd(
      adUnitId: 'ca-app-pub-2034009761866400/9537477650',
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (_isDisposed) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd?.dispose();
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Native ad failed to load: $error');
        },
      ),
    );

    newAd.load();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: _isLoaded && _nativeAd != null
          ? SizedBox(
              height: widget.height,
              width: widget.width,
              child: AdWidget(
                key: ValueKey(_nativeAd.hashCode),
                ad: _nativeAd!,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
