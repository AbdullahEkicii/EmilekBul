import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Güncelleme sonrası ilk açılışta "Yenilikler" penceresini bir kez göstermek için sürüm takibi.
/// Yeni kurulumda gösterilmez: tanıtım ekranı bitince mevcut sürüm "görüldü" sayılır.
class WhatsNewService {
  static const String _seenKey = 'whats_new_seen_version';

  /// Gösterilmesi gereken sürümü döner (yoksa null).
  /// Anahtar hiç yoksa ve kullanıcı tanıtımı zaten görmüşse (= güncelleme yapan eski kullanıcı) gösterir.
  static Future<String?> pendingVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = (await PackageInfo.fromPlatform()).version;
      final seen = prefs.getString(_seenKey);
      if (seen == current) return null;
      final isExistingUser = prefs.getBool('has_seen_onboarding_v3') ?? false;
      if (seen == null && !isExistingUser) {
        await prefs.setString(_seenKey, current);
        return null;
      }
      return current;
    } catch (_) {
      return null;
    }
  }

  static Future<void> markSeen(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seenKey, version);
    } catch (_) {}
  }

  /// Yeni kurulum: tanıtım tamamlanınca çağrılır, o sürümün notları "görüldü" sayılır.
  static Future<void> markCurrentSeen() async {
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      await markSeen(current);
    } catch (_) {}
  }
}
