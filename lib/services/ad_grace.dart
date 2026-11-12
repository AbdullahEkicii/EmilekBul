import 'package:shared_preferences/shared_preferences.dart';

/// Yeni kullanıcılar için reklam sessiz dönemi.
/// İlk açılıştan itibaren [graceDays] gün VE [graceTests] tamamlanmış test (solo, günlük ve düello birlikte) geçene kadar
/// yerel (native), banner ve geçiş reklamı gösterilmez. Ödüllü reklam (kullanıcının
/// kendi isteğiyle) bu dönemden etkilenmez.
class AdGrace {
  static const int graceDays = 10;
  static const int graceTests = 5;

  static const _firstOpenKey = 'ads_first_open_ms';
  static const _testsKey = 'ads_completed_tests';

  /// Uygulama açılışında ilk açılış zamanını bir kez kaydeder.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_firstOpenKey)) {
      await prefs.setInt(_firstOpenKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Sessiz dönem hâlâ sürüyor mu? Gün ve test koşulları birlikte sağlanana kadar true.
  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    final firstOpen = prefs.getInt(_firstOpenKey);
    if (firstOpen == null) return true;
    final days = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(firstOpen)).inDays;
    final tests = prefs.getInt(_testsKey) ?? 0;
    return days < graceDays || tests < graceTests;
  }
}
