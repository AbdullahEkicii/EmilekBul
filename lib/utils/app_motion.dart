import 'package:flutter/widgets.dart';
import '../services/performance_service.dart';

/// Tek noktadan hareket kararı: sistemin "animasyonları azalt" ayarı ya da
/// performans modu açıksa efektler sadeleşir (anlık geçiş, döngü yok).
class AppMotion {
  AppMotion._();

  static bool reduced(BuildContext context) =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
      PerformanceService.isPerformanceMode;

  /// Sürekli döngüler (nabız, yüzen ışık) yalnızca hareket açıkken çalışsın.
  static bool loopsAllowed(BuildContext context) => !reduced(context);

  /// Azaltılmış harekette süre sıfıra iner.
  static Duration duration(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;
}
