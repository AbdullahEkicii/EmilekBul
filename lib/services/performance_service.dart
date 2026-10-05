import 'dart:ui' show ImageFilter;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerformanceService {
  static bool _performanceModeEnabled = false;
  static bool _isInitialized = false;

  /// Initializes the performance service and loads preference
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _performanceModeEnabled = prefs.getBool('performance_mode') ?? true;
      _isInitialized = true;
    } catch (e) {
      debugPrint('PerformanceService init error: $e');
    }
  }

  static bool get isPerformanceMode => _performanceModeEnabled;

  /// Performans modunda pahalı BackdropFilter blur'ünü atlar (animasyonlar etkilenmez).
  static Widget blur({required double sigma, required Widget child}) {
    if (_performanceModeEnabled) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }

  /// Enables or disables performance mode
  static Future<void> setPerformanceMode(bool enabled) async {
    _performanceModeEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('performance_mode', enabled);
    } catch (e) {
      debugPrint('Error saving performance setting: $e');
    }
  }
}
