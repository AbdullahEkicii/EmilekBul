import 'package:shared_preferences/shared_preferences.dart';
import 'remote_flags.dart';

/// Yeni kullanıcılar için reklam sessiz dönemi.
/// İlk açılıştan itibaren [graceDays] gün VE [graceTests] tamamlanmış test koşullarının
/// ikisi de henüz aşılmadıysa (ikisi birden sağlanıyorsa) banner ve geçiş reklamı gösterilmez.
/// Kullanıcı gün sınırını VEYA test sınırını aştığında sessiz dönem sona erer.
/// Ödüllü reklam (kullanıcının kendi isteğiyle) bu dönemden etkilenmez.
class AdGrace {
  static int get graceDays => RemoteFlags.adGraceDays;
  static int get graceTests => RemoteFlags.adGraceTests;

  static const _firstOpenKey = 'ads_first_open_ms';
  static const _testsKey = 'ads_completed_tests';

  /// Uygulama açılışında ilk açılış zamanını bir kez kaydeder.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_firstOpenKey)) {
      await prefs.setInt(_firstOpenKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Saf karar fonksiyonu (test edilebilir).
  /// Gün < [graceDays] VE tamamlanan test < [graceTests] olduğu sürece true döner.
  static bool isActiveFor({
    required int daysSinceFirstOpen,
    required int completedTests,
    int? graceDaysOverride,
    int? graceTestsOverride,
  }) {
    final targetDays = graceDaysOverride ?? graceDays;
    final targetTests = graceTestsOverride ?? graceTests;
    return daysSinceFirstOpen < targetDays && completedTests < targetTests;
  }

  /// Sessiz dönem hâlâ sürüyor mu?
  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    final firstOpen = prefs.getInt(_firstOpenKey);
    if (firstOpen == null) return true;
    final days = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(firstOpen)).inDays;
    final tests = prefs.getInt(_testsKey) ?? 0;
    return isActiveFor(daysSinceFirstOpen: days, completedTests: tests);
  }
}
