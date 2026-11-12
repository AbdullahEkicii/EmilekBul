import 'package:flutter/material.dart';

/// Apple HIG'den esinlenen renk tokenları (iOS koyu mod sistem renkleri).
/// Netlik: yüksek kontrast metin. Derinlik: katmanlar arasında ince ışık ve gölge.
class AppColors {
  AppColors._();

  static const Color backgroundTop = Color(0xFF0B1020);
  static const Color backgroundBottom = Color(0xFF111A2E);
  static const Color surface = Color(0xFF1C2438);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0x99EBEBF5); // iOS label secondary
  static const Color textTertiary = Color(0x4DEBEBF5);

  static const Color accent = Color(0xFF0A84FF); // iOS systemBlue
  static const Color success = Color(0xFF30D158); // iOS systemGreen
  static const Color danger = Color(0xFFFF453A); // iOS systemRed
  static const Color warning = Color(0xFFFF9F0A); // iOS systemOrange
  static const Color gold = Color(0xFFFFD60A); // iOS systemYellow
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
