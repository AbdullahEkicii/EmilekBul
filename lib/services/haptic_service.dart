import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cevap geri bildirimi için titreşim (haptic). Ayarlardan kapatılabilir.
class HapticService {
  static const String _key = 'haptics_enabled';
  static bool _enabled = true;
  static bool _loaded = false;

  static bool get isEnabled => _enabled;

  static Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_key) ?? true;
      _loaded = true;
    } catch (e) {
      debugPrint('HapticService init error: $e');
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (e) {
      debugPrint('Error saving haptics setting: $e');
    }
  }

  /// Ham dokunuş çağrıları: tüm uygulama bunları kullanır, böylece ayar her yerde geçerli olur.
  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  /// Doğru cevap: kısa, hafif dokunuş.
  static void correct() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  /// Yanlış cevap: daha belirgin, çift darbe.
  static void wrong() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 90), HapticFeedback.mediumImpact);
  }

  /// Kusursuz test gibi büyük anlar için güçlü kutlama titreşimi.
  static void celebrate() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 120), HapticFeedback.mediumImpact);
    Future.delayed(const Duration(milliseconds: 260), HapticFeedback.heavyImpact);
  }
}
