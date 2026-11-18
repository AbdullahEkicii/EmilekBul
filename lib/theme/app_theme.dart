import 'package:flutter/material.dart';

/// Ferah, aydınlık ve göz yormayan "Coastal Twilight / Sky-Aurora" renk sistemi.
/// Netlik: yüksek kontrastlı alçıtaşı beyazı metin ve berrak semantik vurgular.
/// Derinlik: koyu çamur siyahı yerine nefes alan safir-gökyüzü katmanları ve ince speküler kenarlar.
class AppColors {
  AppColors._();

  // Airy Luminous Background Canvas (açık nefes alan gökyüzü-safir derinliği)
  static const Color backgroundTop = Color(0xFF152943);
  static const Color backgroundMiddle = Color(0xFF1E3A5F);
  static const Color backgroundBottom = Color(0xFF172D4A);
  static const Color scaffoldGradientStart = Color(0xFF152943);
  static const Color scaffoldGradientEnd = Color(0xFF213F66);
  static const Color onboardingBackground = Color(0xFF12233A);

  // Elevated Frosted Surfaces
  static const Color surface = Color(0xFF213A5C);
  static const Color surfaceElevated = Color(0xFF2A4870);
  static const Color dialogSurface = Color(0xFF1E3554);
  static const Color border = Color(0x33E0F2FE);

  // Crisp High-Contrast Ink
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xCCBAE6FD);
  static const Color textMuted = Color(0xFF94B4D4);
  static const Color textTertiary = Color(0x66BAE6FD);

  // Cohesive Uplifting Accents
  static const Color accent = Color(0xFF38BDF8); // Refreshing Sky Cyan
  static const Color accentSecondary = Color(0xFFFBBF24); // Sunlit Honey Gold
  static const Color cyan = Color(0xFF22D3EE);
  static const Color cyanDark = Color(0xFF0EA5E9);

  static const Color indigo = Color(0xFF60A5FA);
  static const Color indigoDark = Color(0xFF3B82F6);
  static const Color indigoLight = Color(0xFF93C5FD);

  static const Color purple = Color(0xFFA78BFA);
  static const Color violet = Color(0xFF8B5CF6);

  static const Color success = Color(0xFF34D399); // Fresh Sea Mint
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF059669);

  static const Color danger = Color(0xFFFB7185); // Soft Rose Coral
  static const Color coral = Color(0xFFF43F5E);
  static const Color warning = Color(0xFFFBBF24);
  static const Color amber = Color(0xFFFBBF24);
  static const Color amberDark = Color(0xFFF59E0B);
  static const Color gold = Color(0xFFFDE047);
  static const Color goldSoft = Color(0xFFFBBF24);

  /// Tüm ana ekranlarda paylaşılan ferah, iç açıcı gökyüzü arka plan gradyanı.
  static const LinearGradient airyBackgroundGradient = LinearGradient(
    colors: [
      backgroundTop,
      backgroundMiddle,
      backgroundBottom,
    ],
    stops: [0.0, 0.52, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cam kenarlıklarda ince prizmatik ışık çerçevesi.
  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [
      Color(0x55FFFFFF),
      Color(0x2238BDF8),
      Color(0x28FBBF24),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Köşe yarıçapları (iOS: kart 20-28, buton pill).
class AppRadius {
  AppRadius._();

  static const double small = 12;
  static const double button = 16;
  static const double card = 22;
  static const double sheet = 28;
  static const double pill = 999;
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = TextTheme(
      // Apple tipografi hiyerarşisi: büyük başlık, başlık, gövde, yardımcı metin.
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.2),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.1),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0),
    ).apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundTop,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      textTheme: base,
      // Apple: dokunmada yayılan ripple yerine yumuşak, sade geri bildirim.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1FFFFFFF), thickness: 0.5, space: 0.5),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
    );
  }
}
