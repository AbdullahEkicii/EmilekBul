import 'package:flutter/material.dart';

class MyNativeAd extends StatelessWidget {
  final double height;
  final double width;
  final String factoryId;
  final int? refreshInterval; // seconds

  // Reklam hesabı hazır olana kadar kapalı tutuyoruz
  static const bool adsEnabled = false;

  const MyNativeAd({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.factoryId = 'adFactoryExample',
    this.refreshInterval,
  });

  @override
  Widget build(BuildContext context) {
    if (!adsEnabled) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }
}
