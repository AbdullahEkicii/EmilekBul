import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../widgets/my_native_ad.dart';

class loading_screen extends StatelessWidget {
  const loading_screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7F7CFF), Color(0xFFA67BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Ana içerik - merkezi alan
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo + dönerken büyüyen/küçülen animasyon
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween(begin: 0.8, end: 1.2),
                      curve: Curves.easeInOut,
                      builder: (context, scale, _) => Transform.scale(
                        scale: scale,
                        child: const Icon(
                          Icons.psychology_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Parçalı ışıltılı progress bar
                    SizedBox(
                      width: 240,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 6,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Neon-glow alt yazı
                    DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      child: AnimatedTextKit(
                        animatedTexts: [
                          ColorizeAnimatedText(
                            'Yapay Zeka Testinizi hazırlıyor...',
                            textAlign: TextAlign.center,
                            textStyle: TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                            ),
                            colors: [
                              Colors.white,
                              Colors.white70,
                              Colors.white
                            ],
                            speed: const Duration(milliseconds: 800),
                          ),
                        ],
                        totalRepeatCount: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Native Ad - Sayfanın en altına eklendi
          //  SafeArea(
           //   child: Padding(
            //    padding:
           //         const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
           //     child: MyNativeAd(),
          //    ),
          //  ),
          ],
        ),
      ),
    );
  }
}
